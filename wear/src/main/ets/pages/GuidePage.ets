import { common } from '@kit.AbilityKit';
import { distributedKVStore, preferences } from '@kit.ArkData';

interface GuideSnapshot {
  status: string;
  taskId?: string;
  taskTitle: string;
  stepText: string;
  updatedAt: number;
}

interface GuideTask {
  title: string;
  completed: boolean;
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
  @State lang: number = 0;
  @State hint: string = '';
  private stamp: number = 0;
  private pref: preferences.Preferences | undefined;
  private store: distributedKVStore.SingleKVStore | undefined;
  private pollTimer: number = -1;
  private breakTimer: number = -1;

  aboutToAppear(): void {
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
      const taskPref = await preferences.getPreferences(context, 'wear_focux');
      const language = await taskPref.get('language', 0);
      this.lang = language === 1 ? 1 : 0;
      this.pref = await preferences.getPreferences(context, 'wear_guide');
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
      if (this.status === 'breaking_down') {
        this.scheduleConfirmation();
      }
      this.pollTimer = setInterval(() => this.pullRemote(), 1500);
    } catch (_e) {
      this.hint = this.tr('仅本机可用', 'Local only');
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
        if (this.status === 'breaking_down') {
          this.scheduleConfirmation();
        }
      } else if (this.stamp > 0 && (!remote || this.stamp > remote.updatedAt)) {
        await this.store.put(GUIDE_KEY, JSON.stringify(this.snapshot()));
      }
    } catch (_e) {
      // Keep local state when the other device is unavailable.
    }
  }

  private async saveLocal(): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(LOCAL_KEY, JSON.stringify(this.snapshot()));
    await this.pref.flush();
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
      this.hint = this.tr('已本机保存', 'Saved locally');
    }
  }

  private async chooseTask(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const taskPref = await preferences.getPreferences(context, 'wear_focux');
      const raw = await taskPref.get('tasks_json', '');
      if (typeof raw === 'string' && raw.length > 0) {
        const tasks = JSON.parse(raw) as GuideTask[];
        const pending = tasks.find((task: GuideTask) => !task.completed);
        if (pending) {
          this.taskTitle = pending.title;
        }
      }
    } catch (_e) {
      this.hint = this.tr('暂无待办任务', 'No pending task');
    }
  }

  private async breakDown(): Promise<void> {
    const title = this.taskTitle.trim();
    if (title.length === 0) {
      await this.chooseTask();
    }
    if (this.taskTitle.trim().length === 0) {
      this.hint = this.tr('请先在手机添加任务', 'Add a task on phone');
      return;
    }
    this.stepText = this.tr(`先为「${this.taskTitle}」专注做 5 分钟`, `Work on "${this.taskTitle}" for 5 minutes`);
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

  private label(): string {
    switch (this.status) {
      case 'listening': return this.tr('正在听', 'Listening');
      case 'breaking_down': return this.tr('拆成小步', 'Breaking down');
      case 'awaiting_confirmation': return this.tr('等你确认', 'Confirm');
      case 'first_step': return this.tr('先做一步', 'First step');
      case 'in_progress': return this.tr('正在进行', 'In progress');
      case 'paused': return this.tr('暂停一下', 'Paused');
      case 'step_complete': return this.tr('这一步完成', 'Completed');
      default: return this.tr('随时开始', 'Ready');
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
    Column() {
      Text('‹')
        .fontSize(20)
        .fontColor(Color.White)
        .width(28)
        .height(25)
        .textAlign(TextAlign.Center)
        .onClick(() => this.getUIContext().getRouter().back())
      Scroll() {
        Column({ space: 5 }) {
          Image(this.icon())
            .width(116)
            .height(87)
            .objectFit(ImageFit.Contain)
            .backgroundColor('#F7F9F5')
            .borderRadius(12)
          Text(this.label())
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
          if (this.taskTitle.length > 0) {
            Text(this.taskTitle)
              .fontSize(10)
              .fontColor('#D7D7D7')
              .maxLines(2)
              .textAlign(TextAlign.Center)
          }
          if (this.stepText.length > 0 && this.status !== 'ready') {
            Text(this.stepText)
              .fontSize(10)
              .fontColor('#A7D493')
              .maxLines(3)
              .textAlign(TextAlign.Center)
          }
          if (this.status === 'ready') {
            Button(this.tr('使用待办', 'Use task'))
              .onClick(() => this.chooseTask())
            Button(this.tr('请手机听我说', 'Use phone voice'))
              .onClick(() => this.changeStatus('listening'))
            Button(this.tr('拆成小步', 'Make a step'))
              .onClick(() => this.breakDown())
          } else if (this.status === 'listening') {
            Text(this.tr('在手机上开始语音输入', 'Start voice input on phone'))
              .fontSize(10)
              .fontColor('#D7D7D7')
            Button(this.tr('使用待办', 'Use task'))
              .onClick(async () => {
                await this.chooseTask();
                await this.breakDown();
              })
          } else if (this.status === 'awaiting_confirmation') {
            Button(this.tr('确认', 'Confirm'))
              .onClick(() => this.changeStatus('first_step'))
          } else if (this.status === 'first_step') {
            Button(this.tr('开始', 'Start'))
              .onClick(() => this.changeStatus('in_progress'))
          } else if (this.status === 'in_progress') {
            Button(this.tr('暂停', 'Pause'))
              .onClick(() => this.changeStatus('paused'))
            Button(this.tr('完成', 'Done'))
              .onClick(() => this.changeStatus('step_complete'))
          } else if (this.status === 'paused') {
            Button(this.tr('继续', 'Resume'))
              .onClick(() => this.changeStatus('in_progress'))
            Button(this.tr('完成', 'Done'))
              .onClick(() => this.changeStatus('step_complete'))
          } else if (this.status === 'step_complete') {
            Button(this.tr('下一步', 'Next step'))
              .onClick(() => {
                this.stepText = '';
                this.changeStatus('ready');
              })
          }
          if (this.hint.length > 0) {
            Text(this.hint)
              .fontSize(9)
              .fontColor('#C8C8C8')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 34, right: 34, top: 20, bottom: 25 })
    .backgroundColor('#202420')
    .borderRadius('50%')
    .clip(true)
  }
}
