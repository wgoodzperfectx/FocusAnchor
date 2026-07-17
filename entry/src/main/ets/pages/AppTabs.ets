import { promptAction } from '@kit.ArkUI';
import { AppState } from '../services/AppState';
import { FocusLevel, focusLevelColor, StudyMethod, StudyTask } from '../models/AppTypes';
import { ReminderService } from '../services/ReminderService';
import { XiaoyiBridge } from '../services/XiaoyiBridge';
import { focusLevelLabel, methodLabel, t } from '../common/LocaleHelper';

@Component
export struct HomeTab {
  @Link refreshToken: number;
  @Prop lang: number = 0;
  @Prop clockText: string = '';
  private appState: AppState = AppState.getInstance();

  private tx(key: string): string {
    return t(key, this.lang);
  }

  private level(): FocusLevel {
    return this.appState.latestHeartRate?.focusLevel ?? 'green';
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Text(`${this.tx('home_overview')}`)
          .fontSize($r('app.float.title_font'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)
          .opacity(this.lang >= 0 ? 1 : 1)

        Text(`${this.tx('system_time')} ${this.clockText}`)
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)

        Column({ space: 8 }) {
          Text(this.tx('metric_heart_rate'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
          Text(`${this.appState.latestHeartRate?.bpm ?? '--'} ${this.tx('bpm_unit')}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(`${this.tx('metric_focus_status')}: ${focusLevelLabel(this.level(), this.lang)}`)
            .fontSize(14)
            .fontColor(focusLevelColor(this.level()))
          Text(this.tx('xiaoyi_hr_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(12)

        Button(this.tx('btn_focus'))
          .width('100%')
          .height(52)
          .fontSize(18)
          .fontColor(Color.White)
          .backgroundColor('#555555')
          .border({ width: 1, color: Color.White })
          .opacity(this.lang >= 0 ? 1 : 1)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/FocusPage' })
              .catch(() => {
              });
          })

        Button(this.tx('btn_remind'))
          .width('100%')
          .height(44)
          .fontColor(Color.White)
          .backgroundColor('#444444')
          .opacity(this.lang >= 0 ? 1 : 1)
          .onClick(async () => {
            await ReminderService.getInstance().remindNow(this.appState.getPendingTasks());
            promptAction.showToast({ message: this.tx('reminder_title') });
            this.refreshToken++;
          })
      }
      .padding(20)
      .width('100%')
    }
    .backgroundColor($r('app.color.page_background'))
    .height('100%')
    .onVisibleAreaChange([0.0, 1.0], () => {
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
  @State editingId: string = '';
  @State selectedId: string = '';
  @State draftTitle: string = '';
  @State draftContent: string = '';
  @State draftMinutes: string = '25';
  @State draftDeadline: string = '';
  @State draftMethod: string = 'reading';
  @State draftPriority: number = 2;
  @State draftInsight: string = '';
  @State advisingId: string = '';
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

  private defaultDeadlineText(): string {
    return this.formatDeadlineText(Date.now() + 24 * 60 * 60 * 1000);
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

  private parseDeadline(text: string): number {
    const trimmed = text.trim();
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
    return Date.now() + 24 * 60 * 60 * 1000;
  }

  private openNew(): void {
    this.editingId = '';
    this.selectedId = '';
    this.draftTitle = '';
    this.draftContent = '';
    this.draftMinutes = '25';
    this.draftDeadline = this.defaultDeadlineText();
    this.draftMethod = 'reading';
    this.draftPriority = 2;
    this.draftInsight = '';
    this.showEditor = true;
  }

  private selectTask(task: StudyTask): void {
    this.selectedId = task.id;
    this.editingId = task.id;
    this.draftTitle = task.title;
    this.draftContent = task.content;
    this.draftMinutes = `${task.studyMinutes}`;
    this.draftDeadline = this.formatDeadlineText(task.dueAt ?? task.createdAt);
    this.draftMethod = task.studyMethod;
    this.draftPriority = task.basePriority ?? task.priority;
    this.draftInsight = task.insight ?? '';
    this.showEditor = true;
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
    await this.refreshFromLocal();
    promptAction.showToast({ message: this.tx('task_saved_view') });
  }

  private async clearSelected(): Promise<void> {
    if (this.selectedId.length === 0) {
      return;
    }
    await this.appState.clearTask(this.selectedId);
    this.selectedId = '';
    this.editingId = '';
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

  private async requestAdvice(task: StudyTask): Promise<void> {
    this.advisingId = task.id;
    const level = this.appState.latestHeartRate?.focusLevel ?? 'green';
    const label = this.bridge.focusLabel(level);
    const advice = await this.bridge.askAdvice(task, label);
    task.insight = advice;
    await this.appState.updateTask(task);
    this.advisingId = '';
    this.reloadPending();
    this.refreshToken++;
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
          Button(this.tx('btn_voice_add'))
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#666666')
            .enabled(!this.voiceBusy)
            .onClick(async () => await this.voiceAddAndSave())
          Button(this.tx('btn_add_task'))
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#555555')
            .onClick(() => this.openNew())
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })

      if (this.showEditor) {
        Column({ space: 10 }) {
          Text(this.editingId.length > 0 ? this.tx('edit_task') : this.tx('btn_add_task'))
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.draftTitle, placeholder: this.tx('task_title') })
            .fontColor(Color.White)
            .placeholderColor('#AAAAAA')
            .backgroundColor('#444444')
            .onChange((value: string) => this.draftTitle = value)
          TextArea({ text: this.draftContent, placeholder: this.tx('learning_content') })
            .height(70)
            .fontColor(Color.White)
            .placeholderColor('#AAAAAA')
            .backgroundColor('#444444')
            .onChange((value: string) => this.draftContent = value)
          Text(this.tx('deadline_label'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.draftDeadline, placeholder: this.tx('due_time') })
            .fontColor(Color.White)
            .placeholderColor('#AAAAAA')
            .backgroundColor('#444444')
            .onChange((value: string) => this.draftDeadline = value)
          Row({ space: 6 }) {
            Button(this.tx('priority_high'))
              .layoutWeight(1)
              .height(36)
              .fontSize(12)
              .backgroundColor(this.draftPriority === 1 ? '#777777' : '#444444')
              .fontColor(Color.White)
              .onClick(() => this.draftPriority = 1)
            Button(this.tx('priority_medium'))
              .layoutWeight(1)
              .height(36)
              .fontSize(12)
              .backgroundColor(this.draftPriority === 2 ? '#777777' : '#444444')
              .fontColor(Color.White)
              .onClick(() => this.draftPriority = 2)
            Button(this.tx('priority_low'))
              .layoutWeight(1)
              .height(36)
              .fontSize(12)
              .backgroundColor(this.draftPriority === 3 ? '#777777' : '#444444')
              .fontColor(Color.White)
              .onClick(() => this.draftPriority = 3)
          }
          .width('100%')
          Button(this.voiceBusy ? this.tx('voice_listening') : this.tx('btn_voice'))
            .width('100%')
            .height(36)
            .fontSize(13)
            .backgroundColor('#555555')
            .fontColor(Color.White)
            .enabled(!this.voiceBusy)
            .onClick(async () => await this.voiceInput())
          Row({ space: 12 }) {
            Button(this.tx('btn_save'))
              .layoutWeight(1)
              .fontColor(Color.White)
              .backgroundColor('#555555')
              .onClick(async () => await this.saveTask())
            Button(this.tx('btn_cancel'))
              .layoutWeight(1)
              .backgroundColor('#333333')
              .fontColor(Color.White)
              .onClick(() => {
                this.showEditor = false;
              })
          }
          .width('100%')
          if (this.selectedId.length > 0) {
            Button(this.tx('btn_clear'))
              .width('100%')
              .height(40)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.danger'))
              .onClick(async () => await this.clearSelected())
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }

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
              Text(`${this.tx('deadline_label')}: ${this.formatDeadlineText(task.dueAt ?? task.createdAt)}`)
                .fontSize($r('app.float.caption_font'))
                .fontColor($r('app.color.text_secondary'))
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
              if (this.selectedId === task.id) {
                Row({ space: 8 }) {
                  Button(this.tx('btn_xiaoyi_advice'))
                    .layoutWeight(1)
                    .height(32)
                    .fontSize(12)
                    .fontColor(Color.White)
                    .backgroundColor('#555555')
                    .enabled(this.advisingId !== task.id)
                    .onClick(async () => await this.requestAdvice(task))
                  Button(this.tx('btn_clear'))
                    .layoutWeight(1)
                    .height(32)
                    .fontSize(12)
                    .fontColor(Color.White)
                    .backgroundColor($r('app.color.danger'))
                    .onClick(async () => {
                      this.selectedId = task.id;
                      await this.clearSelected();
                    })
                }
                .width('100%')
              }
            }
            .padding(16)
            .width('100%')
            .backgroundColor(this.selectedId === task.id ? '#4A4A4A' : $r('app.color.surface'))
            .borderRadius(14)
            .border({
              width: this.selectedId === task.id ? 1 : 0,
              color: Color.White
            })
            .onClick(() => this.selectTask(task))
            .animation({ duration: 250, curve: Curve.EaseInOut })
          }
          .transition({ type: TransitionType.Insert, opacity: 0, translate: { y: 20 } })
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
    .backgroundColor($r('app.color.page_background'))
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
