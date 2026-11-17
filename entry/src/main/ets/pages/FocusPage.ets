import { AppState } from '../services/AppState';
import { FlashNote, StudyTask } from '../models/AppTypes';
import { FocusSessionService } from '../services/FocusSessionService';
import { common } from '@kit.AbilityKit';
import { CompanionView } from '../components/CompanionView';
import { selectUnambiguousTask } from './CurrentTaskSelection';
import { flashSyncState, UiFlashSyncState } from './UiReadModels';

@Component
export struct FocusContent {
  @Prop embedded: boolean = false;
  @Prop @Watch('onRefreshToken') refreshToken: number = 0;
  onClose: () => void = () => {};
  @State lang: number = 0;
  @State task: StudyTask | undefined = undefined;
  @State flashNotes: FlashNote[] = [];
  @State sessionStatus: string = 'IDLE';
  @State actionError: string = '';
  @State confirmConvertId: string = '';
  @State confirmArchiveId: string = '';
  @State busy: boolean = false;
  private appState: AppState = AppState.getInstance();
  private flashPollTimer: number = -1;

  aboutToAppear(): void {
    this.lang = this.appState.settings.language ?? 0;
    this.refreshWorkspace();
    this.flashPollTimer = setInterval(() => {
      this.flashNotes = [...this.appState.flashNotes.filter((note: FlashNote) => !note.archived)];
    }, 1500);
  }

  onPageShow(): void {
    this.refreshWorkspace();
  }

  onRefreshToken(): void {
    this.refreshWorkspace();
  }

  aboutToDisappear(): void {
    if (this.flashPollTimer !== -1) clearInterval(this.flashPollTimer);
    this.flashPollTimer = -1;
  }

  private async refreshWorkspace(): Promise<void> {
    try {
    await this.appState.reloadTasksFromDisk();
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    const requested = params?.['taskId'] ?? '';
    const current = requested ? this.appState.getPendingTasks().find((item: StudyTask) => item.id === requested) :
      selectUnambiguousTask(this.appState.tasks);
    this.task = current;
    this.flashNotes = [...this.appState.flashNotes.filter((note: FlashNote) => !note.archived)];
    this.sessionStatus = 'IDLE';
    if (current?.focusStep?.actionId) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const session = await FocusSessionService.load(context);
      this.sessionStatus = session && session.actionId === current.focusStep.actionId ? session.status : 'IDLE';
    }
    this.actionError = '';
    } catch (_error) {
      this.actionError = this.lang === 1 ? '暂时无法读取主线任务。' : 'Could not load the current task.';
      this.task = undefined;
    }
  }

  private async convertFlash(flashId: string): Promise<void> {
    if (this.confirmConvertId !== flashId) {
      this.confirmConvertId = flashId;
      return;
    }
    this.busy = true;
    this.actionError = '';
    try {
      const taskId = await this.appState.convertFlashToTask(flashId);
      if (!taskId) throw new Error('conversion unavailable');
      this.confirmConvertId = '';
      await this.refreshWorkspace();
    } catch (_error) {
      this.actionError = this.lang === 1 ? '转为任务失败，可稍后重试。' : 'Could not convert this note. Retry later.';
    } finally {
      this.busy = false;
    }
  }

  private async archiveFlash(flashId: string): Promise<void> {
    if (this.confirmArchiveId !== flashId) {
      this.confirmArchiveId = flashId;
      return;
    }
    try {
      await this.appState.archiveFlash(flashId);
      this.confirmArchiveId = '';
      this.flashNotes = [...this.appState.flashNotes.filter((note: FlashNote) => !note.archived)];
      this.actionError = '';
    } catch (_error) {
      this.actionError = this.lang === 1 ? '暂时无法归档，请重试。' : 'Could not archive this note. Please retry.';
    }
  }

  private openStep(): void {
    if (!this.task?.id) return;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/StepSessionPage', params: { taskId: this.task.id } }).catch(() => {});
  }

  private syncLabel(status: UiFlashSyncState): string {
    if (status === 'SYNCED') return this.lang === 1 ? '已同步' : 'Synced';
    if (status === 'FAILED') return this.lang === 1 ? '同步失败' : 'Sync failed';
    if (status === 'LOCAL') return this.lang === 1 ? '仅保存在本机' : 'Saved locally';
    if (status === 'PENDING') return this.lang === 1 ? '待同步' : 'Pending sync';
    return this.lang === 1 ? '同步状态未知' : 'Sync status unknown';
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text(this.lang === 1 ? 'Focus · 闪念沙盒' : 'Focus · Flash sandbox')
          .fontSize(23).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Blank()
        if (!this.embedded) {
          Text(this.lang === 1 ? '返回' : 'Back').fontSize(15).fontColor($r('app.color.primary'))
            .accessibilityText(this.lang === 1 ? '返回上一页' : 'Go back')
            .onClick(() => this.onClose())
        }
      }.width('100%')

      Column({ space: 8 }) {
        Text(this.lang === 1 ? '当前主线' : 'Current thread').fontSize(12).fontColor('#66736A')
        if (this.task?.focusStep) {
          Text(this.task.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary')).maxLines(2)
          Text(this.task.focusStep.text).fontSize(14).fontColor($r('app.color.text_secondary')).maxLines(2)
          if (this.task.focusStep.status !== 'completed') {
            Button(this.lang === 1 ? '回到这一步' : 'Return to this step')
              .width('100%').height(44).fontColor(Color.White).backgroundColor($r('app.color.primary')).onClick(() => this.openStep())
          } else {
            Text(this.lang === 1 ? '这一步已完成' : 'This step is complete').fontSize(12).fontColor($r('app.color.primary'))
          }
          if (this.sessionStatus === 'RUNNING' || this.task.focusStep.status === 'in_progress') {
            Text(this.lang === 1 ? '行动进行中' : 'Action in progress').fontSize(12).fontColor($r('app.color.primary'))
          } else if (this.sessionStatus === 'PAUSED' || this.task.focusStep.status === 'paused') {
            Text(this.lang === 1 ? '行动已暂停' : 'Action paused').fontSize(12).fontColor('#8A641A')
          }
        } else {
          Text(this.lang === 1 ? '当前没有唯一的进行中步骤。可从任务列表选择一条主线。' : 'No single current step. Choose a thread from Tasks.')
            .fontSize(14).fontColor($r('app.color.text_secondary'))
        }
      }.width('100%').padding(16).backgroundColor('#F1F6EC').borderRadius(18)

      Row() {
        Text(this.lang === 1 ? '已替你记下的闪念' : 'Flash notes').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Blank()
        Text(`${this.flashNotes.length}`).fontSize(13).fontColor('#66736A')
      }.width('100%')

      if (this.flashNotes.length === 0) {
        Column({ space: 8 }) {
          Text(this.lang === 1 ? '突然想到什么，可以先用手表记下来。' : 'Capture a thought on your watch and return to it here.')
            .fontSize(14).fontColor($r('app.color.text_secondary'))
          Text(this.lang === 1 ? '当前不提供跨设备录入状态保证。' : 'Cross-device capture availability is not confirmed.')
            .fontSize(12).fontColor('#7A827B')
        }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(16)
      } else {
        List({ space: 10 }) {
          ForEach(this.flashNotes, (note: FlashNote) => {
            ListItem() {
              Column({ space: 10 }) {
                Text(note.content).width('100%').fontSize(15).fontColor($r('app.color.text_primary')).maxLines(5)
                Row() {
                  Text(this.syncLabel(flashSyncState(note.syncStatus as string)))
                    .fontSize(12).fontColor(flashSyncState(note.syncStatus as string) === 'SYNCED' ? $r('app.color.primary') : '#8A641A')
                  Blank()
                  Text(new Date(note.createdAt).toLocaleString()).fontSize(11).fontColor('#7A827B')
                }.width('100%')
                Row({ space: 8 }) {
                  Button(this.confirmConvertId === note.flashId ? (this.lang === 1 ? '再次点击确认' : 'Tap again to confirm') :
                    note.convertedTaskId ? (this.lang === 1 ? '已转为任务' : 'Converted') : (this.lang === 1 ? '转为任务' : 'Make task'))
                    .layoutWeight(1).height(44).backgroundColor($r('app.color.primary_soft')).fontColor($r('app.color.text_primary'))
                    .enabled(!note.convertedTaskId && !this.busy).onClick(async () => await this.convertFlash(note.flashId))
                  Button(this.lang === 1 ? '稍后处理' : 'Later').height(44).backgroundColor('#F1F3EF').fontColor($r('app.color.text_secondary'))
                    .onClick(() => { this.confirmConvertId = ''; this.confirmArchiveId = ''; })
                  Button(this.confirmArchiveId === note.flashId ? (this.lang === 1 ? '确认归档' : 'Confirm') : (this.lang === 1 ? '归档' : 'Archive'))
                    .height(44).backgroundColor('#F1F3EF').fontColor($r('app.color.text_secondary'))
                    .onClick(async () => await this.archiveFlash(note.flashId))
                }.width('100%')
              }.width('100%').padding(14).backgroundColor($r('app.color.surface')).borderRadius(16)
            }
          }, (note: FlashNote) => note.flashId)
        }.layoutWeight(1).edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Auto)
      }

      Row({ space: 8 }) {
        CompanionView({ placement: 'FOCUS', interactionState: this.flashNotes.length > 0 ? 'FLASH_SAVED' : 'IDLE', compact: true,
          message: this.lang === 1 ? '先把闪念放在这里，准备好时再处理。' : 'Leave thoughts here until you are ready.' })
        Text(this.lang === 1 ? '先把闪念放在这里，准备好时再处理。' : 'Leave thoughts here until you are ready.')
          .layoutWeight(1).fontSize(12).fontColor('#66736A')
      }.width('100%')
      if (this.actionError.length > 0) Text(this.actionError).fontSize(13).fontColor('#A13C32').width('100%')
    }
    .width('100%').height('100%').padding({ left: 20, right: 20, top: 18, bottom: 12 })
    .backgroundColor($r('app.color.page_background'))
  }
}

@Entry
@Component
struct FocusPage {
  build() {
    Column() {
      FocusContent({ onClose: () => this.getUIContext().getRouter().back() })
    }.width('100%').height('100%')
  }
}
