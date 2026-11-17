import { AppState } from '../services/AppState';
import { StudyTask, FocusStepStatus } from '../models/AppTypes';
import { proposeFirstStep } from '../focusanchoragentextability/FocusAnchorRouter';
import { CompanionView, CompanionInteraction } from '../components/CompanionView';
import { FocusSessionService } from '../services/FocusSessionService';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct StepSessionPage {
  @State lang: number = 0;
  @State task: StudyTask | undefined = undefined;
  @State state: CompanionInteraction = 'IDLE';
  @State retryState: CompanionInteraction = 'IDLE';
  @State draftStep: string = '';
  @State providerQuestion: string = '';
  @State providerAnswer: string = '';
  @State errorText: string = '';
  @State busy: boolean = false;
  @State editing: boolean = false;
  @State sessionPaused: boolean = false;
  private appState: AppState = AppState.getInstance();

  aboutToAppear(): void {
    this.lang = this.appState.settings.language ?? 0;
    this.loadTask();
  }

  private tr(cn: string, en: string): string {
    return this.lang === 1 ? cn : en;
  }

  private async loadTask(): Promise<void> {
    try {
      await this.appState.reloadTasksFromDisk();
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
      const taskId = params?.['taskId'] ?? '';
      const selected = this.appState.tasks.find((item: StudyTask) => item.id === taskId);
      if (!selected) {
        this.errorText = this.tr('找不到这项任务。请返回任务列表重试。', 'Task unavailable. Return to Tasks and retry.');
        this.state = 'ERROR';
        return;
      }
      this.task = selected;
      this.draftStep = selected.focusStep?.text ?? '';
      this.state = selected.focusStep && selected.focusStep.status !== 'completed' ? 'SAVED' : 'IDLE';
      if (selected.focusStep?.actionId) {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const session = await FocusSessionService.load(context);
        this.sessionPaused = session?.actionId === selected.focusStep.actionId && session.status === 'PAUSED';
      }
    } catch (_error) {
      this.errorText = this.tr('暂时无法读取任务。', 'Could not load this task.');
      this.state = 'ERROR';
    }
  }

  private propose(): void {
    if (!this.task || this.busy) return;
    const proposed = proposeFirstStep(this.task, this.appState.settings.privacy.consentFocusSupport !== false);
    if (!proposed) {
      this.errorText = this.tr('当前无法提供建议。请检查授权或任务内容。', 'Suggestion unavailable. Check consent or task details.');
      this.state = 'ERROR';
      return;
    }
    this.draftStep = proposed;
    this.state = 'FALLBACK';
  }

  private async acceptStep(): Promise<void> {
    if (!this.task || !this.draftStep.trim() || this.busy) return;
    this.busy = true;
    try {
      await this.appState.confirmGuidedStep(this.task.id, this.task.title, this.draftStep.trim());
      await this.appState.reloadTasksFromDisk();
      const saved = this.appState.tasks.find((item: StudyTask) => item.id === this.task?.id);
      if (!saved?.focusStep?.actionId || saved.focusStep.text !== this.draftStep.trim()) {
        throw new Error('action not persisted');
      }
      this.task = saved;
      this.state = 'SAVED';
      this.editing = false;
    } catch (_error) {
      this.errorText = this.tr('这一步未能保存，请重试。', 'This step was not saved. Please retry.');
      this.retryState = 'FALLBACK';
      this.state = 'ERROR';
    } finally {
      this.busy = false;
    }
  }

  private async setStatus(next: FocusStepStatus): Promise<void> {
    if (!this.task?.focusStep?.actionId || this.busy) return;
    this.busy = true;
    this.errorText = '';
    try {
      await this.appState.setGuidedStepStatus(this.task.id, next);
      await this.appState.reloadTasksFromDisk();
      const updated = this.appState.tasks.find((item: StudyTask) => item.id === this.task?.id);
      if (!updated?.focusStep) throw new Error('action missing');
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const session = await FocusSessionService.load(context);
      if (next === 'paused') {
        if (session?.actionId !== updated.focusStep.actionId || session?.status !== 'PAUSED') throw new Error('pause not saved');
      } else if (next === 'in_progress' && this.sessionPaused) {
        if (session?.actionId !== updated.focusStep.actionId || session?.status !== 'RUNNING') throw new Error('resume not saved');
      } else if (updated.focusStep.status !== next) {
        throw new Error('status unchanged');
      }
      this.task = updated;
      this.sessionPaused = session?.actionId === updated.focusStep.actionId && session?.status === 'PAUSED';
      if (next === 'completed') this.state = 'COMPLETE';
    } catch (_error) {
      this.errorText = this.tr('状态未能保存，请重试。', 'The action state was not saved. Please retry.');
    } finally {
      this.busy = false;
    }
  }

  private message(): string {
    if (this.state === 'ERROR') return this.tr('暂时没有完成。', 'That did not work yet.');
    if (this.state === 'LOADING') return this.tr('正在等待步骤建议。', 'Waiting for a step suggestion.');
    if (this.state === 'CLARIFY') return this.tr('我还想确认一件事。', 'One thing needs clarification.');
    if (this.state === 'STEP') return this.tr('先从这一小步开始。', 'Start with this small step.');
    if (this.state === 'FALLBACK') return this.tr('先试试这个简化建议。', 'Try this simple suggestion.');
    if (this.state === 'SAVED') {
      if (this.sessionPaused) return this.tr('随时可以继续。', 'Resume when you are ready.');
      if (this.task?.focusStep?.status === 'in_progress') return this.tr('我们接着做这一小步。', 'Let’s continue this step.');
      return this.tr('这一步已经记下了。', 'This step is saved.');
    }
    if (this.state === 'COMPLETE') return this.tr('这一步完成了。', 'This step is complete.');
    return this.tr('我们先找到第一小步。', 'Let’s find the first small step.');
  }

  private visualState(): CompanionInteraction {
    if (this.state !== 'SAVED') return this.state;
    if (this.sessionPaused) return 'PAUSED';
    return this.task?.focusStep?.status === 'in_progress' ? 'ACTIVE' : 'SAVED';
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Text('‹').fontSize(30).fontColor('#25332C').width(42)
          .accessibilityText(this.tr('返回任务', 'Back to Tasks'))
          .onClick(() => this.getUIContext().getRouter().back())
        Text(this.tr('第一小步', 'First step')).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#25332C')
        Blank()
      }.width('100%')

      Scroll() {
        Column({ space: 18 }) {
          CompanionView({ placement: 'STEP_SESSION', interactionState: this.visualState(),
            message: this.message(), compact: false })
          if (this.task) {
            Text(this.task.title).width('100%').fontSize(15).fontColor('#526259').maxLines(3)
          }
          if (this.state === 'CLARIFY' && this.providerQuestion.length > 0) {
            Column({ space: 10 }) {
              Text(this.providerQuestion).width('100%').fontSize(17).fontColor('#25332C')
              TextArea({ text: this.providerAnswer, placeholder: this.tr('补充你的回答', 'Add your answer') })
                .height(100).backgroundColor('#F1F6EC').fontColor('#25332C')
                .onChange((value: string) => this.providerAnswer = value)
            }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(18)
          }
          if (this.state === 'STEP' || this.state === 'FALLBACK' || this.state === 'SAVED' || this.state === 'COMPLETE') {
            Column({ space: 9 }) {
              Text(this.state === 'FALLBACK' ? this.tr('本地规则建议 · 尚未保存', 'Local rule suggestion · unsaved') :
                this.state === 'STEP' ? this.tr('Agent 建议 · 尚未确认', 'Agent suggestion · unconfirmed') :
                  this.tr('已确认的第一步', 'Confirmed first step'))
                .fontSize(12).fontColor('#66736A').width('100%')
              if (this.editing && this.state === 'FALLBACK') {
                TextArea({ text: this.draftStep, placeholder: this.tr('写下具体可做的一步', 'Write a concrete first step') })
                  .height(110).backgroundColor('#FFFFFF').fontColor('#25332C')
                  .onChange((value: string) => this.draftStep = value)
              } else {
                Text(this.draftStep).width('100%').fontSize(18).fontColor('#25332C').maxLines(8)
              }
              if ((this.state === 'SAVED' || this.state === 'COMPLETE') && this.task?.focusStep) {
                Text(this.task.focusStep.generationSource === 'rule' ?
                  this.tr('来源：本地规则', 'Source: local rule') :
                  this.tr('来源：已保存的行动', 'Source: saved action'))
                  .fontSize(12).fontColor('#66736A').width('100%')
              }
            }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(18)
          }
          if (this.errorText.length > 0) {
            Text(this.errorText).width('100%').fontSize(13).fontColor('#A13C32')
          }
        }.width('100%').padding({ top: 22, bottom: 14 })
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring)

      if (this.state === 'IDLE') {
        Button(this.tr('生成第一步', 'Create first step')).width('100%').height(50)
          .fontColor(Color.White).backgroundColor('#386A45').onClick(() => this.propose())
      } else if (this.state === 'LOADING') {
        Button(this.tr('取消等待', 'Cancel waiting')).width('100%').height(50)
          .backgroundColor('#E9EFE7').fontColor('#25332C')
          .onClick(() => this.getUIContext().getRouter().back())
      } else if (this.state === 'CLARIFY') {
        Button(this.tr('提交回答', 'Submit answer')).width('100%').height(50)
          .fontColor(Color.White).backgroundColor('#386A45').enabled(false)
      } else if (this.state === 'STEP') {
        Button(this.tr('接受这一步', 'Accept this step')).width('100%').height(50)
          .fontColor(Color.White).backgroundColor('#386A45').enabled(false)
      } else if (this.state === 'FALLBACK') {
        Button(this.tr('接受并保存', 'Accept and save')).width('100%').height(50)
          .fontColor(Color.White).backgroundColor('#386A45').enabled(!this.busy)
          .onClick(async () => await this.acceptStep())
        Button(this.editing ? this.tr('完成修改', 'Done editing') : this.tr('自己改', 'Edit suggestion'))
          .width('100%').height(38).backgroundColor('#E9EFE7').fontColor('#25332C')
          .onClick(() => this.editing = !this.editing)
      } else if (this.state === 'SAVED' && this.task?.focusStep) {
        if (this.task.focusStep.status === 'ready' || this.sessionPaused) {
          Button(this.sessionPaused ? this.tr('继续这一步', 'Resume this step') : this.tr('开始这一步', 'Start this step'))
            .width('100%').height(50).fontColor(Color.White).backgroundColor('#386A45').enabled(!this.busy)
            .onClick(async () => await this.setStatus('in_progress'))
        } else if (this.task.focusStep.status === 'in_progress') {
          Button(this.tr('完成这一步', 'Complete this step')).width('100%').height(50)
            .fontColor(Color.White).backgroundColor('#386A45').enabled(!this.busy)
            .onClick(async () => await this.setStatus('completed'))
          Button(this.tr('暂停', 'Pause')).width('100%').height(38).backgroundColor('#E9EFE7').fontColor('#25332C')
            .enabled(!this.busy).onClick(async () => await this.setStatus('paused'))
        } else {
          Button(this.tr('返回任务', 'Back to Tasks')).width('100%').height(50)
            .fontColor(Color.White).backgroundColor('#386A45').onClick(() => this.getUIContext().getRouter().back())
        }
      } else if (this.state === 'COMPLETE') {
        Button(this.tr('返回任务', 'Back to Tasks')).width('100%').height(50)
          .fontColor(Color.White).backgroundColor('#386A45').onClick(() => this.getUIContext().getRouter().back())
      } else if (this.state === 'ERROR') {
        Button(this.tr('重试', 'Retry')).width('100%').height(50).fontColor(Color.White).backgroundColor('#386A45')
          .onClick(() => {
            this.errorText = '';
            this.state = this.retryState;
            if (!this.task) this.loadTask();
          })
      }
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 12, bottom: 18 })
      .backgroundColor('#FAF9F4')
  }
}
