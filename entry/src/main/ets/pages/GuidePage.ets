import { common } from '@kit.AbilityKit';
import { distributedKVStore, preferences } from '@kit.ArkData';
import { AppState } from '../services/AppState';
import { XiaoyiBridge } from '../services/XiaoyiBridge';
import { proposeFirstStep } from '../focusanchoragentextability/FocusAnchorRouter';

interface GuideSnapshot {
  status: string;
  taskId?: string;
  taskTitle: string;
  stepText: string;
  updatedAt: number;
}

const GUIDE_KEY: string = 'guide_session_sync';
const LOCAL_KEY: string = 'guide_session_local';

@Entry
@Component
struct GuidePage {
  @State status: string = 'ready';
  @State taskTitle: string = '';
  private taskId: string = '';
  @State stepText: string = '';
  @State lang: number = 1;
  @State busy: boolean = false;
  @State hint: string = '';
  private stamp: number = 0;
  private pref: preferences.Preferences | undefined;
  private store: distributedKVStore.SingleKVStore | undefined;
  private pollTimer: number = -1;
  private breakTimer: number = -1;
  private appState: AppState = AppState.getInstance();

  aboutToAppear(): void {
    this.lang = this.appState.settings.language ?? 1;
    this.initSession();
  }

  aboutToDisappear(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    if (this.breakTimer !== -1) {
      clearTimeout(this.breakTimer);
      this.breakTimer = -1;
    }
  }

  private tr(cn: string, en: string): string {
    return this.lang === 1 ? cn : en;
  }

  private snapshot(): GuideSnapshot {
    return { status: this.status, taskId: this.taskId, taskTitle: this.taskTitle,
      stepText: this.stepText, updatedAt: this.stamp };
  }

  private apply(snapshot: GuideSnapshot): void {
    this.status = snapshot.status;
    this.taskTitle = snapshot.taskTitle;
    this.taskId = snapshot.taskId ?? '';
    this.stepText = snapshot.stepText;
    this.stamp = snapshot.updatedAt;
  }

  private parse(raw: string): GuideSnapshot | undefined {
    try {
      const value = JSON.parse(raw) as GuideSnapshot;
      const valid = ['ready', 'listening', 'breaking_down', 'awaiting_confirmation',
        'first_step', 'in_progress', 'paused', 'step_complete'];
      if (valid.indexOf(value.status) < 0 || typeof value.updatedAt !== 'number' ||
        typeof value.taskTitle !== 'string' || typeof value.stepText !== 'string') {
        return undefined;
      }
      return value;
    } catch (_e) {
      return undefined;
    }
  }

  private async initSession(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.pref = await preferences.getPreferences(context, 'focusanchor_guide');
      const raw = await this.pref.get(LOCAL_KEY, '');
      if (typeof raw === 'string') {
        const local = this.parse(raw);
        if (local) {
          this.apply(local);
        }
      }
      const manager = distributedKVStore.createKVManager({
        context: context, bundleName: context.abilityInfo.bundleName
      });
      this.store = await manager.getKVStore<distributedKVStore.SingleKVStore>('focux_watch_sync', {
        createIfMissing: true, encrypt: false, backup: false, autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      });
      await this.pullRemote();
      await this.alignWithTask();
      if (this.status === 'breaking_down') {
        this.scheduleConfirmation();
      }
      this.pollTimer = setInterval(() => this.pullRemote(), 1500);
    } catch (_e) {
      this.hint = this.tr('跨端同步暂不可用；进度保存在本机', 'Sync unavailable; progress stays on this device');
    }
  }

  private async pullRemote(): Promise<void> {
    if (!this.store) {
      return;
    }
    try {
      const raw = await this.store.get(GUIDE_KEY);
      const remote = typeof raw === 'string' ? this.parse(raw) : undefined;
      if (remote && remote.updatedAt > this.stamp) {
        this.apply(remote);
        await this.saveLocal();
        if (this.taskId.length > 0) {
          const stepStatus = this.status === 'in_progress' ? 'in_progress' :
            this.status === 'paused' ? 'paused' :
            this.status === 'step_complete' ? 'completed' : undefined;
          if (stepStatus) {
            await this.appState.setGuidedStepStatus(this.taskId, stepStatus);
          }
        }
        if (this.status === 'breaking_down') {
          this.scheduleConfirmation();
        }
      } else if (this.stamp > 0 && (!remote || this.stamp > remote.updatedAt)) {
        await this.store.put(GUIDE_KEY, JSON.stringify(this.snapshot()));
      }
    } catch (_e) {
      // Offline work continues from the local snapshot.
    }
  }

  private async saveLocal(): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(LOCAL_KEY, JSON.stringify(this.snapshot()));
    await this.pref.flush();
  }

  private async alignWithTask(): Promise<void> {
    if (!this.taskId) {
      return;
    }
    await this.appState.reloadTasksFromDisk();
    const task = this.appState.tasks.find((item) => item.id === this.taskId);
    const step = task?.focusStep;
    if (!step || step.updatedAt <= this.stamp) {
      return;
    }
    this.taskTitle = task?.title ?? this.taskTitle;
    this.stepText = step.text;
    this.status = step.status === 'ready' ? 'first_step' :
      step.status === 'completed' ? 'step_complete' : step.status;
    this.stamp = step.updatedAt;
    await this.saveLocal();
  }

  private async changeStatus(next: string): Promise<void> {
    this.status = next;
    this.stamp = Math.max(Date.now(), this.stamp + 1);
    try {
      await this.saveLocal();
      if (this.store) {
        await this.store.put(GUIDE_KEY, JSON.stringify(this.snapshot()));
      }
    } catch (_e) {
      this.hint = this.tr('已保存在本机，稍后同步', 'Saved locally; sync will retry');
    }
  }

  private chooseTask(): void {
    const task = this.appState.getPendingTasks()[0];
    if (task) {
      this.taskTitle = task.title;
      this.taskId = task.id;
    }
  }

  private async listen(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    await this.changeStatus('listening');
    try {
      const spoken = await XiaoyiBridge.getInstance().speechToText();
      if (spoken.trim().length > 0) {
        this.taskTitle = spoken.trim();
        await this.breakDown();
      } else {
        this.hint = this.tr('没有听清，可重试或手动输入', 'No speech detected; retry or type');
      }
    } catch (_e) {
      this.hint = this.tr('语音不可用，可手动输入', 'Voice unavailable; type instead');
    } finally {
      this.busy = false;
    }
  }

  private async breakDown(): Promise<void> {
    const title = this.taskTitle.trim();
    if (title.length === 0) {
      this.hint = this.tr('先输入任务', 'Enter a task first');
      return;
    }
    this.taskTitle = title;
    const task = this.appState.tasks.find((item) => item.id === this.taskId);
    const candidate = task ?? this.appState.createBlankTask();
    candidate.title = title;
    const proposed = proposeFirstStep(candidate,
      this.appState.settings.privacy.consentFocusSupport === true);
    if (!proposed) {
      this.hint = this.tr('请检查专注授权或换一个普通任务',
        'Check focus consent or choose another task');
      return;
    }
    this.stepText = this.lang === 1 ? proposed :
      (task?.content.trim() ?? '').length > 0 ? proposed :
        `Open "${title}" and begin for 2 minutes`;
    await this.changeStatus('breaking_down');
    this.scheduleConfirmation();
  }

  private scheduleConfirmation(): void {
    if (this.breakTimer !== -1) {
      clearTimeout(this.breakTimer);
    }
    this.breakTimer = setTimeout(() => {
      if (this.status === 'breaking_down') {
        this.changeStatus('awaiting_confirmation');
      }
      this.breakTimer = -1;
    }, 700);
  }

  private async confirmStep(): Promise<void> {
    this.taskId = await this.appState.confirmGuidedStep(this.taskId, this.taskTitle, this.stepText);
    await this.changeStatus('first_step');
  }

  private async stepAction(status: 'in_progress' | 'paused' | 'completed', pageStatus: string): Promise<void> {
    await this.appState.setGuidedStepStatus(this.taskId, status);
    await this.changeStatus(pageStatus);
  }

  private label(): string {
    switch (this.status) {
      case 'listening': return this.tr('正在听', 'Listening');
      case 'breaking_down': return this.tr('拆成小步', 'Breaking it down');
      case 'awaiting_confirmation': return this.tr('等你确认', 'Waiting for you');
      case 'first_step': return this.tr('先做一步', 'One small step');
      case 'in_progress': return this.tr('正在进行', 'In progress');
      case 'paused': return this.tr('暂停一下', 'Paused');
      case 'step_complete': return this.tr('这一步完成', 'Step complete');
      default: return this.tr('随时开始', 'Ready when you are');
    }
  }

  private icon(): Resource {
    switch (this.status) {
      case 'listening': return $r('app.media.status_listening');
      case 'breaking_down': return $r('app.media.status_breaking_down');
      case 'awaiting_confirmation': return $r('app.media.status_awaiting_confirmation');
      case 'first_step': return $r('app.media.status_first_step');
      case 'in_progress': return $r('app.media.status_in_progress');
      case 'paused': return $r('app.media.status_paused');
      case 'step_complete': return $r('app.media.status_step_complete');
      default: return $r('app.media.status_ready');
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹')
          .fontSize(32)
          .fontColor('#252925')
          .onClick(() => this.getUIContext().getRouter().back())
        Text(this.tr('引导一步', 'Guided step'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#252925')
        Blank()
      }
      .width('100%')

      Image(this.icon())
        .width(230)
        .height(173)
        .objectFit(ImageFit.Contain)
      Text(this.label())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#252925')

      if (this.status === 'ready' || this.status === 'listening' ||
        this.status === 'breaking_down' || this.status === 'awaiting_confirmation') {
        TextInput({ text: this.taskTitle, placeholder: this.tr('输入要做的任务', 'Task to work on') })
          .width('100%')
          .onChange((value: string) => {
            this.taskTitle = value;
            this.taskId = '';
          })
      } else {
        Text(this.taskTitle)
          .fontSize(18)
          .fontColor('#252925')
          .maxLines(2)
      }

      if (this.status === 'awaiting_confirmation') {
        TextInput({ text: this.stepText, placeholder: this.tr('编辑第一小步', 'Edit the first step') })
          .width('100%')
          .onChange((value: string) => { this.stepText = value; })
      } else if (this.stepText.length > 0 && this.status !== 'ready') {
        Text(this.stepText)
          .fontSize(15)
          .fontColor('#515951')
          .maxLines(3)
      }

      if (this.status === 'ready' || this.status === 'listening') {
        Button(this.tr('使用待办第一项', 'Use next task'))
          .onClick(() => this.chooseTask())
        Button(this.tr('语音说出任务', 'Speak task'))
          .enabled(!this.busy)
          .onClick(() => this.listen())
        Button(this.tr('拆成小步', 'Create first step'))
          .onClick(() => this.breakDown())
      } else if (this.status === 'awaiting_confirmation') {
        Button(this.tr('确认这一步', 'Confirm step'))
          .onClick(() => this.confirmStep())
      } else if (this.status === 'first_step') {
        Button(this.tr('开始执行', 'Start'))
          .onClick(() => this.stepAction('in_progress', 'in_progress'))
      } else if (this.status === 'in_progress') {
        Button(this.tr('暂停一下', 'Pause'))
          .onClick(() => this.stepAction('paused', 'paused'))
        Button(this.tr('完成这一步', 'Complete step'))
          .onClick(() => this.stepAction('completed', 'step_complete'))
      } else if (this.status === 'paused') {
        Button(this.tr('继续', 'Resume'))
          .onClick(() => this.stepAction('in_progress', 'in_progress'))
        Button(this.tr('完成这一步', 'Complete step'))
          .onClick(() => this.stepAction('completed', 'step_complete'))
      } else if (this.status === 'step_complete') {
        Button(this.tr('开始下一步', 'Start another step'))
          .onClick(() => {
            this.stepText = '';
            this.changeStatus('ready');
          })
      }

      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(12)
          .fontColor('#6B756B')
      }
      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(22)
    .backgroundColor('#F7F9F5')
    .alignItems(HorizontalAlign.Center)
  }
}
