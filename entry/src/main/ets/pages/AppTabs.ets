import { promptAction } from '@kit.ArkUI';
import { AppState } from '../services/AppState';
import { StudyMethod, StudyTask } from '../models/AppTypes';
import { ReminderService } from '../services/ReminderService';
import { XiaoyiBridge } from '../services/XiaoyiBridge';
import { t } from '../common/LocaleHelper';
import { CompanionView, CompanionInteraction } from '../components/CompanionView';
import { selectUnambiguousTask } from './CurrentTaskSelection';
import { FocusSessionService } from '../services/FocusSessionService';
import { common } from '@kit.AbilityKit';

@Component
export struct HomeTab {
  @Link refreshToken: number;
  @Prop lang: number = 0;
  onOpenTasks: () => void = () => {};
  onOpenSettings: () => void = () => {};
  private appState: AppState = AppState.getInstance();
  @State showMonitor: boolean = false;
  @State pausedActionId: string = '';

  aboutToAppear(): void {
    this.refreshSession();
  }

  private async refreshSession(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const session = await FocusSessionService.load(context);
      this.pausedActionId = session?.status === 'PAUSED' ? session.actionId : '';
    } catch (_error) {
      this.pausedActionId = '';
    }
  }

  private tx(key: string): string {
    return t(key, this.lang);
  }

  private currentTask(): StudyTask | undefined {
    return selectUnambiguousTask(this.appState.tasks);
  }

  private homeMessage(): string {
    const task = this.currentTask();
    if (!task) return this.appState.getPendingTasks().length === 0 ?
      (this.lang === 1 ? '先记下一件想做的事。' : 'Let’s write down one thing to do.') :
      (this.lang === 1 ? '从任务里选一件，作为眼前的主线。' : 'Choose one task to work on now.');
    if (!task.focusStep) return this.lang === 1 ? '要不要从第一小步开始？' : 'Shall we find the first small step?';
    if (task.focusStep.status === 'completed') return this.lang === 1 ? '这一步完成了。' : 'This step is done.';
    if (task.focusStep.status === 'paused' || task.focusStep.actionId === this.pausedActionId) {
      return this.lang === 1 ? '随时可以回来。' : 'Come back whenever you are ready.';
    }
    if (task.focusStep.status === 'in_progress') return this.lang === 1 ? '我们接着做这一小步。' : 'Let’s continue this small step.';
    return this.lang === 1 ? '这一步已经准备好了。' : 'This step is ready.';
  }

  private homeAction(): string {
    const task = this.currentTask();
    if (!task) return this.appState.getPendingTasks().length === 0 ?
      (this.lang === 1 ? '记下一件事' : 'Add a task') : (this.lang === 1 ? '查看任务' : 'View tasks');
    if (!task.focusStep) return this.lang === 1 ? '拆成第一步' : 'Create a first step';
    if (task.focusStep.status === 'completed') return this.lang === 1 ? '查看下一步' : 'View next step';
    if (task.focusStep.status === 'ready') return this.lang === 1 ? '开始这一步' : 'Start this step';
    return this.lang === 1 ? '继续这一步' : 'Continue this step';
  }

  private companionState(): CompanionInteraction {
    const step = this.currentTask()?.focusStep;
    if (!step) return 'IDLE';
    if (step.status === 'completed') return 'COMPLETE';
    if (step.status === 'paused' || step.actionId === this.pausedActionId) return 'PAUSED';
    return step.status === 'in_progress' ? 'ACTIVE' : 'STEP';
  }

  private openStep(task: StudyTask): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/StepSessionPage', params: { taskId: task.id } }).catch(() => {});
  }

  @Builder
  private monitorSheet() {
    Column({ space: 12 }) {
      Row() {
        Text(this.lang === 1 ? '手表与监测' : 'Watch and monitoring')
          .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#25332C')
        Blank()
        Button(this.lang === 1 ? '关闭' : 'Close').height(36).backgroundColor('#E9EFE7').fontColor('#25332C')
          .onClick(() => this.showMonitor = false)
      }.width('100%')
      Text(this.lang === 1 ? '手表连接：未知' : 'Watch connection: Unknown')
        .width('100%').fontSize(14).fontColor('#526259')
      Text(this.appState.monitoring ?
        (this.lang === 1 ? '本地监测服务已启动；设备来源未确认' : 'Local monitoring is running; device source unverified') :
        (this.lang === 1 ? '监测：已停止' : 'Monitoring: Stopped'))
        .width('100%').fontSize(14).fontColor('#526259')
      if (this.appState.latestHeartRate) {
        Text(`${this.lang === 1 ? '最近数据' : 'Latest sample'}: ${new Date(this.appState.latestHeartRate.timestamp).toLocaleString()}`)
          .width('100%').fontSize(12).fontColor('#66736A')
        Text(this.appState.latestHeartRate.isSimulated === false ?
          (this.lang === 1 ? '数据来源待设备线确认' : 'Source pending device verification') :
          (this.lang === 1 ? '模拟数据 · 不是设备监测' : 'Simulated data · not device monitoring'))
          .width('100%').fontSize(12).fontColor('#8A641A')
      } else {
        Text(this.lang === 1 ? '暂无传感器数据。连接功能尚未接入。' : 'No sensor data. Device connection is not available yet.')
          .width('100%').fontSize(12).fontColor('#66736A')
      }
    }.width('100%').padding(22).backgroundColor('#FFFFFF')
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Row({ space: 7 }) {
          Column().width(12).height(12).backgroundColor('#6FA86D').borderRadius(3)
          Text(this.lang === 1 ? '手表状态' : 'Watch status').fontSize(13).fontColor('#526259')
        }
          .height(48).padding({ left: 8, right: 8 })
          .accessibilityText(this.lang === 1 ? '查看手表连接和监测状态' : 'View watch connection and monitoring status')
          .onClick(() => this.showMonitor = !this.showMonitor)
        Blank()
        Text('⚙')
          .fontSize(24).fontColor('#25332C').width(48).height(48)
          .textAlign(TextAlign.Center)
          .accessibilityText(this.lang === 1 ? '打开设置' : 'Open settings')
          .onClick(() => this.onOpenSettings())
      }.width('100%').padding({ left: 14, right: 10, top: 6 })

      Column({ space: 0 }) {
        if (this.appState.dataError.length > 0) {
          Text(this.lang === 1 ? this.appState.dataError : 'Local data could not be loaded. Check storage and retry.')
            .fontSize(13).fontColor('#A13C32').width('100%')
        }
        CompanionView({ placement: 'HOME', interactionState: this.companionState(), compact: false,
          message: this.homeMessage() })
          .layoutWeight(1)
        Text(this.homeMessage())
          .fontSize(23).fontWeight(FontWeight.Medium).fontColor('#25332C')
          .textAlign(TextAlign.Center).width('100%').maxLines(3)
        if (this.currentTask()) {
          Text(this.currentTask()?.focusStep?.text ?? this.currentTask()?.title ?? '')
            .fontSize(15).fontColor('#526259').textAlign(TextAlign.Center)
            .width('100%').maxLines(2).margin({ top: 10 })
        } else if (this.appState.getPendingTasks().length > 0) {
          Text(this.lang === 1 ? '请在任务页选择当前行动' : 'Choose the current action in Tasks')
            .fontSize(14).fontColor('#526259').textAlign(TextAlign.Center)
            .width('100%').margin({ top: 10 })
        }
        Button(this.homeAction())
          .width('100%').height(54).margin({ top: 24, bottom: 18 })
          .fontSize(18).fontColor(Color.White).backgroundColor('#386A45')
          .onClick(() => {
            const task = this.currentTask();
            if (task?.focusStep?.status === 'completed') {
              this.onOpenTasks();
            } else if (task) {
              this.openStep(task);
            } else {
              this.onOpenTasks();
            }
          })
      }
        .width('100%').layoutWeight(1)
        .padding({ left: 24, right: 24 })
    }
    .backgroundColor('#FAF9F4')
    .height('100%')
    .width('100%')
    .bindSheet(this.showMonitor, this.monitorSheet(), {
      onDisappear: () => { this.showMonitor = false; }
    })
    .onVisibleAreaChange([0.0, 1.0], () => {
      this.refreshSession();
      this.refreshToken++;
    })
  }
}

@Component
export struct TasksTab {
  @Link @Watch('onRefreshToken') refreshToken: number;
  @Prop lang: number = 0;
  private appState: AppState = AppState.getInstance();
  private bridge: XiaoyiBridge = XiaoyiBridge.getInstance();
  @State showEditor: boolean = false;
  @State showMoreOptions: boolean = false;
  @State quickTitle: string = '';
  @State taskError: string = '';
  @State deleteArmed: boolean = false;
  @State editingId: string = '';
  @State selectedId: string = '';
  @State draftTitle: string = '';
  @State draftContent: string = '';
  @State draftMinutes: string = '25';
  @State draftDeadline: string = '';
  @State draftMethod: string = 'reading';
  @State draftPriority: number = 2;
  @State draftInsight: string = '';
  @State pendingTasks: StudyTask[] = [];
  @State voiceBusy: boolean = false;
  private escalateTimer: number = -1;

  private tx(key: string): string {
    return t(key, this.lang);
  }

  onRefreshToken(): void {
    this.reloadPending();
    this.tryOpenEditorFromFloat();
  }

  aboutToAppear(): void {
    this.reloadPending();
    this.tryOpenEditorFromFloat();
    this.escalateTimer = setInterval(async () => {
      const changed = await this.appState.refreshDeadlinePriorities();
      if (changed) {
        this.reloadPending();
        this.refreshToken++;
      }
    }, 60 * 1000);
  }

  private tryOpenEditorFromFloat(): void {
    if (this.appState.consumeOpenEditor()) {
      this.openNew();
      this.reloadPending();
    }
  }

  aboutToDisappear(): void {
    if (this.escalateTimer !== -1) {
      clearInterval(this.escalateTimer);
      this.escalateTimer = -1;
    }
  }

  private reloadPending(): void {
    // New array reference so ArkUI always re-renders the visible list
    this.pendingTasks = [...this.appState.getPendingTasks()];
  }

  private async refreshFromLocal(): Promise<void> {
    await this.appState.reloadTasksFromDisk();
    this.reloadPending();
    this.refreshToken++;
  }

  private formatDeadlineText(ts: number): string {
    const d = new Date(ts);
    const y = d.getFullYear();
    const mo = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const hh = d.getHours().toString().padStart(2, '0');
    const mi = d.getMinutes().toString().padStart(2, '0');
    return `${y}-${mo}-${day} ${hh}:${mi}`;
  }

  private parseDeadline(text: string): number | undefined {
    const trimmed = text.trim();
    if (trimmed.length === 0) return undefined;
    // YYYY-MM-DD HH:mm
    const matched = trimmed.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})$/);
    if (matched) {
      const y = Number.parseInt(matched[1]);
      const mo = Number.parseInt(matched[2]) - 1;
      const day = Number.parseInt(matched[3]);
      const hh = Number.parseInt(matched[4]);
      const mi = Number.parseInt(matched[5]);
      const dt = new Date(y, mo, day, hh, mi, 0, 0).getTime();
      if (!Number.isNaN(dt)) {
        return dt;
      }
    }
    const asNum = Number.parseInt(trimmed);
    if (!Number.isNaN(asNum) && asNum > 100000) {
      return asNum;
    }
    return undefined;
  }

  private openNew(): void {
    this.editingId = '';
    this.selectedId = '';
    this.draftTitle = '';
    this.draftContent = '';
    this.draftMinutes = '25';
    this.draftDeadline = '';
    this.draftMethod = 'reading';
    this.draftPriority = 2;
    this.draftInsight = '';
    this.showMoreOptions = false;
    this.deleteArmed = false;
    this.showEditor = true;
  }

  private selectTask(task: StudyTask): void {
    this.selectedId = task.id;
    this.editingId = task.id;
    this.draftTitle = task.title;
    this.draftContent = task.content;
    this.draftMinutes = `${task.studyMinutes}`;
    this.draftDeadline = task.dueAt ? this.formatDeadlineText(task.dueAt) : '';
    this.draftMethod = task.studyMethod;
    this.draftPriority = task.basePriority ?? task.priority;
    this.draftInsight = task.insight ?? '';
    this.showMoreOptions = false;
    this.deleteArmed = false;
    this.showEditor = true;
  }

  private async quickAdd(): Promise<void> {
    const title = this.quickTitle.trim();
    if (!title) return;
    this.taskError = '';
    try {
      const task = this.appState.createBlankTask();
      task.title = title;
      task.content = '';
      task.dueAt = undefined;
      task.priority = 2;
      task.basePriority = 2;
      await this.appState.addTask(task);
      this.quickTitle = '';
      await this.refreshFromLocal();
    } catch (_error) {
      this.taskError = this.lang === 1 ? '任务未能保存，请重试。' : 'Task could not be saved. Please retry.';
    }
  }

  private openStepSession(task: StudyTask): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/StepSessionPage', params: { taskId: task.id } }).catch(() => {});
  }

  private selectedTask(): StudyTask | undefined {
    return this.pendingTasks.find((item: StudyTask) => item.id === this.selectedId);
  }

  private wasEscalated(task: StudyTask): boolean {
    const base = task.basePriority ?? task.priority;
    return task.priority < base;
  }

  private priorityLabel(priority: number): string {
    if (priority === 1) {
      return this.tx('priority_high');
    }
    if (priority === 3) {
      return this.tx('priority_low');
    }
    return this.tx('priority_medium');
  }

  private async saveTask(): Promise<void> {
    if (!this.draftTitle.trim()) {
      return;
    }
    const dueAt = this.parseDeadline(this.draftDeadline);
    if (this.draftDeadline.trim().length > 0 && dueAt === undefined) {
      this.taskError = this.lang === 1 ? '请按 YYYY-MM-DD HH:mm 填写截止时间。' : 'Use YYYY-MM-DD HH:mm for the deadline.';
      return;
    }
    this.taskError = '';
    try {
    if (this.editingId.length > 0) {
      const existing = this.appState.tasks.find((item: StudyTask) => item.id === this.editingId);
      if (existing) {
        existing.title = this.draftTitle.trim();
        existing.content = this.draftContent.trim();
        existing.studyMinutes = Number.parseInt(this.draftMinutes) || 25;
        existing.studyMethod = this.draftMethod as StudyMethod;
        existing.basePriority = this.draftPriority;
        existing.priority = this.draftPriority;
        existing.dueAt = dueAt;
        existing.insight = this.draftInsight;
        await this.appState.updateTask(existing);
      }
    } else {
      const task = this.appState.createBlankTask();
      task.title = this.draftTitle.trim();
      task.content = this.draftContent.trim();
      task.studyMinutes = Number.parseInt(this.draftMinutes) || 25;
      task.studyMethod = this.draftMethod as StudyMethod;
      task.basePriority = this.draftPriority;
      task.priority = this.draftPriority;
      task.dueAt = dueAt;
      task.insight = this.draftInsight;
      await this.appState.addTask(task);
      this.selectedId = task.id;
    }
    await this.appState.refreshDeadlinePriorities();
    this.showEditor = false;
    this.deleteArmed = false;
    await this.refreshFromLocal();
    promptAction.showToast({ message: this.tx('task_saved_view') });
    } catch (_error) {
      this.taskError = this.lang === 1 ? '任务未能保存，请重试。' : 'Task could not be saved. Please retry.';
    }
  }

  private async clearSelected(): Promise<void> {
    if (this.selectedId.length === 0) {
      return;
    }
    await this.appState.clearTask(this.selectedId);
    this.selectedId = '';
    this.editingId = '';
    this.deleteArmed = false;
    this.showEditor = false;
    await this.refreshFromLocal();
  }

  /** Xiaoyi voice → fill editor (and open it if needed). */
  private async voiceInput(): Promise<void> {
    if (this.voiceBusy) {
      return;
    }
    this.voiceBusy = true;
    if (!this.showEditor) {
      this.openNew();
    }
    promptAction.showToast({ message: this.tx('voice_listening') });
    try {
      const text = await this.bridge.speechToText();
      if (this.draftTitle.trim().length === 0) {
        this.draftTitle = text;
      } else {
        this.draftContent = `${this.draftContent}${this.draftContent.length > 0 ? ' ' : ''}${text}`;
      }
      promptAction.showToast({ message: `${this.tx('voice_ok')}: ${text}` });
    } catch (error) {
      promptAction.showToast({ message: this.tx('voice_fail') });
    } finally {
      this.voiceBusy = false;
    }
  }

  /** One-tap: Xiaoyi voice capture then save as a new incomplete task for the list. */
  private async voiceAddAndSave(): Promise<void> {
    if (this.voiceBusy) {
      return;
    }
    this.openNew();
    this.voiceBusy = true;
    promptAction.showToast({ message: this.tx('voice_listening') });
    try {
      const text = await this.bridge.speechToText();
      this.draftTitle = text;
      this.voiceBusy = false;
      await this.saveTask();
    } catch (error) {
      this.voiceBusy = false;
      promptAction.showToast({ message: this.tx('voice_fail') });
    }
  }

  build() {
    Column({ space: 10 }) {
      Column({ space: 8 }) {
        Text(this.tx('study_tasks'))
          .fontSize($r('app.float.title_font'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 8 }) {
          TextInput({ text: this.quickTitle, placeholder: this.lang === 1 ? '记下一件想做的事…' : 'Write one thing to do…' })
            .layoutWeight(1).height(46).backgroundColor('#FFFFFF').fontColor('#25332C')
            .onChange((value: string) => this.quickTitle = value)
          Button(this.lang === 1 ? '添加' : 'Add').height(44).fontColor(Color.White).backgroundColor('#386A45')
            .onClick(async () => await this.quickAdd())
        }.width('100%')
        Row({ space: 8 }) {
          Button(this.tx('btn_voice_add'))
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#526259')
            .enabled(!this.voiceBusy)
            .onClick(async () => await this.voiceAddAndSave())
          Button(this.lang === 1 ? '更多字段' : 'More fields')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#E4F1DA')
            .fontColor('#25332C')
            .onClick(() => {
              this.openNew();
              this.draftTitle = this.quickTitle;
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })

      if (this.taskError.length > 0) {
        Text(this.taskError).fontSize(13).fontColor('#A13C32').width('100%')
          .padding({ left: 20, right: 20 })
      }

      if (this.showEditor) {
        Scroll() {
        Column({ space: 10 }) {
          Text(this.editingId.length > 0 ? this.tx('edit_task') : this.tx('btn_add_task'))
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.draftTitle, placeholder: this.tx('task_title') })
            .fontColor('#25332C')
            .placeholderColor('#778078')
            .backgroundColor('#FFFFFF')
            .onChange((value: string) => this.draftTitle = value)
          Button(this.showMoreOptions ? (this.lang === 1 ? '收起更多选项' : 'Hide options') : (this.lang === 1 ? '更多选项：内容、时间、优先级' : 'More: notes, deadline, priority'))
            .width('100%').backgroundColor('#E9EFE7').fontColor('#25332C').onClick(() => this.showMoreOptions = !this.showMoreOptions)
          if (this.showMoreOptions) {
          TextArea({ text: this.draftContent, placeholder: this.tx('learning_content') })
            .height(70)
            .fontColor('#25332C')
            .placeholderColor('#778078')
            .backgroundColor('#FFFFFF')
            .onChange((value: string) => this.draftContent = value)
          Text(this.tx('deadline_label'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.draftDeadline, placeholder: this.tx('due_time') })
            .fontColor('#25332C')
            .placeholderColor('#778078')
            .backgroundColor('#FFFFFF')
            .onChange((value: string) => this.draftDeadline = value)
          Row({ space: 6 }) {
            Button(this.tx('priority_high'))
              .layoutWeight(1)
              .height(36)
              .fontSize(12)
              .backgroundColor(this.draftPriority === 1 ? '#E4F1DA' : '#FFFFFF')
              .fontColor('#25332C')
              .onClick(() => this.draftPriority = 1)
            Button(this.tx('priority_medium'))
              .layoutWeight(1)
              .height(36)
              .fontSize(12)
              .backgroundColor(this.draftPriority === 2 ? '#E4F1DA' : '#FFFFFF')
              .fontColor('#25332C')
              .onClick(() => this.draftPriority = 2)
            Button(this.tx('priority_low'))
              .layoutWeight(1)
              .height(36)
              .fontSize(12)
              .backgroundColor(this.draftPriority === 3 ? '#E4F1DA' : '#FFFFFF')
              .fontColor('#25332C')
              .onClick(() => this.draftPriority = 3)
          }
          .width('100%')
          }
          Button(this.voiceBusy ? this.tx('voice_listening') : this.tx('btn_voice'))
            .width('100%')
            .height(36)
            .fontSize(13)
            .backgroundColor('#526259')
            .fontColor(Color.White)
            .enabled(!this.voiceBusy)
            .onClick(async () => await this.voiceInput())
          Row({ space: 12 }) {
            Button(this.tx('btn_save'))
              .layoutWeight(1)
              .fontColor(Color.White)
              .backgroundColor('#386A45')
              .onClick(async () => await this.saveTask())
            Button(this.tx('btn_cancel'))
              .layoutWeight(1)
              .backgroundColor('#E9EFE7')
              .fontColor('#25332C')
              .onClick(() => {
                this.showEditor = false;
                this.deleteArmed = false;
              })
          }
          .width('100%')
          if (this.selectedId.length > 0) {
            Button(this.tx('btn_remind'))
              .width('100%').height(40).backgroundColor('#E4F1DA').fontColor('#25332C')
              .onClick(async () => {
                const selected = this.selectedTask();
                if (selected) {
                  await ReminderService.getInstance().remindNow([selected]);
                  promptAction.showToast({ message: this.tx('reminder_title') });
                }
              })
            Button(this.deleteArmed ? (this.lang === 1 ? '再次点击确认删除' : 'Tap again to delete') : this.tx('btn_clear'))
              .width('100%')
              .height(40)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.danger'))
              .onClick(async () => {
                if (this.deleteArmed) await this.clearSelected();
                else this.deleteArmed = true;
              })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
      } else {

      Text(`${this.tx('pending_list')} (${this.pendingTasks.length})`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)
        .padding({ left: 20, right: 20, top: 4 })

      if (this.pendingTasks.length === 0) {
        Text(this.tx('pending_empty'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 20, right: 20 })
          .alignSelf(ItemAlign.Start)
      }

      List({ space: 10 }) {
        ForEach(this.pendingTasks, (task: StudyTask) => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(task.title)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(this.priorityLabel(task.priority))
                  .fontColor(task.priority === 1 ? '#E74C3C' : $r('app.color.text_secondary'))
              }
              .width('100%')
              if (task.dueAt) {
                Text(`${this.tx('deadline_label')}: ${this.formatDeadlineText(task.dueAt)}`)
                  .fontSize($r('app.float.caption_font')).fontColor($r('app.color.text_secondary'))
              }
              if (this.wasEscalated(task)) {
                Text(this.tx('priority_auto'))
                  .fontSize(12)
                  .fontColor('#E67E22')
              }
              if ((task.insight ?? '').length > 0) {
                Text(`${this.tx('insight_label')}: ${task.insight}`)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
              }
              if (task.focusStep) {
                Text(`${this.lang === 1 ? '第一小步' : 'First step'}: ${task.focusStep.text}`)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
              }
              Row({ space: 8 }) {
                Button(task.focusStep && task.focusStep.status !== 'completed' ?
                  (this.lang === 1 ? '查看这一步' : 'View this step') :
                  (this.lang === 1 ? '拆成第一步' : 'Create first step'))
                  .layoutWeight(1).height(40).fontColor(Color.White).backgroundColor('#386A45')
                  .onClick(() => this.openStepSession(task))
                Button('⋯').width(44).height(40).backgroundColor('#E9EFE7').fontColor('#25332C')
                  .accessibilityText(this.lang === 1 ? '编辑任务' : 'Edit task')
                  .onClick(() => this.selectTask(task))
              }.width('100%')
            }
            .padding(16)
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .border({
              width: this.selectedId === task.id ? 1 : 0,
              color: '#D8E2D7'
            })
          }
        }, (task: StudyTask) =>
          `${task.id}_${task.priority}_${task.dueAt}_${this.lang}_${this.refreshToken}_${task.insight ?? ''}`)
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: 220 })
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)
      .padding({ left: 20, right: 20, bottom: 20 })
      .onAppear(async () => {
        await this.refreshFromLocal();
      })
      }
    }
    .backgroundColor('#FAF9F4')
    .height('100%')
    .onAppear(async () => {
      await this.refreshFromLocal();
      this.tryOpenEditorFromFloat();
    })
    .onVisibleAreaChange([0.0, 1.0], async (_isVisible: boolean, currentRatio: number) => {
      if (currentRatio > 0.3) {
        await this.refreshFromLocal();
        this.tryOpenEditorFromFloat();
      }
    })
  }
}
