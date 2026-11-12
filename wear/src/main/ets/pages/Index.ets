import { common } from '@kit.AbilityKit';
import { distributedKVStore } from '@kit.ArkData';
import { preferences } from '@kit.ArkData';
import { WearActionEvent, WearSyncQueue, shouldAdoptPhoneProjection } from '../services/WearSyncQueue';
import { WearFlashNote, WearFlashQueue, flashIdForSequence } from '../services/WearFlashNoteService';
import { WearCompanionState, WearFlashUiState, WearInteractionState, companionStateLabel, companionVisualId,
  flashTransportState, flashUiLabel, interactionVisualId, primaryStepEvent, selectCurrentAction } from
  '../services/WearUiState';
import { wearVisualResource } from '../services/WearVisualService';

interface WearFocusStep {
  text: string;
  status: string;
  updatedAt: number;
  actionId?: string;
  revision?: number;
  taskId?: string;
  order?: number;
  generationSource?: string;
}

interface WearActionAck {
  eventId: string;
  status: string;
  currentRevision?: number;
}

interface WearTask {
  id: string;
  title: string;
  content: string;
  studyMinutes: number;
  studyMethod: string;
  priority: number;
  basePriority: number;
  completed: boolean;
  createdAt: number;
  dueAt?: number;
  insight?: string;
  focusStep?: WearFocusStep;
}

interface TaskSyncBundle {
  updatedAt: number;
  tasks: WearTask[];
  source?: string;
  currentActionId?: string;
  /** Optional phone-owned user state; consumed when present, not inferred on the watch. */
  companionState?: WearCompanionState;
}

/** Round-watch safe insets (avoid clipping at bezel). */
const SAFE_H: number = 22;
const SAFE_V_TOP: number = 28;
const SAFE_V_BOT: number = 34;

@Entry
@Component
struct Index {
  @State allTasks: WearTask[] = [];
  @State tasks: WearTask[] = [];
  @State statusText: string = '';
  @State currentIndex: number = 0;
  @State lang: number = 0;
  @State currentActionId: string = '';
  @State companionState: WearCompanionState = 'UNKNOWN';
  @State showStepFeedback: boolean = false;
  @State pageSize: number = 200;
  @State pausedActionId: string = '';
  @State syncUnavailable: boolean = false;
  @State flashEditing: boolean = false;
  @State flashDraft: string = '';
  @State flashUiState: WearFlashUiState = 'IDLE';
  @State flashPendingCount: number = 0;
  private kvStore: distributedKVStore.SingleKVStore | undefined = undefined;
  private pref: preferences.Preferences | undefined = undefined;
  private localStamp: number = 0;
  private writing: boolean = false;
  private actionQueue: WearSyncQueue = new WearSyncQueue();
  private actionSequence: number = 1;
  private actionMutation: Promise<void> = Promise.resolve();
  private flashQueue: WearFlashQueue = new WearFlashQueue();
  private flashDeviceId: string = '';
  private flashSequence: number = 1;
  private flashMutation: Promise<void> = Promise.resolve();
  private swiperController: SwiperController = new SwiperController();

  aboutToAppear(): void {
    this.initLocal().then(() => this.initSync());
  }

  onPageShow(): void {
    this.loadLang();
    this.flushActionQueue();
    this.flushFlashQueue();
  }

  /** Content width inside circular safe zone (~70% of diameter). */
  private contentW(): number {
    return Math.max(120, this.pageSize * 0.72);
  }

  private tx(key: string): string {
    if (this.lang === 1) {
      if (key === 'home') {
        return '首页';
      }
      if (key === 'tasks') {
        return '任务';
      }
      if (key === 'focus') {
        return '焦点';
      }
      if (key === 'sync_ok') {
        return '已同步';
      }
      if (key === 'sync_empty') {
        return '暂无任务';
      }
      if (key === 'sync_fail') {
        return '同步不可用';
      }
      if (key === 'sync_pending') {
        return '已保存，待同步';
      }
      if (key === 'sync_conflict') {
        return '步骤已变化，请刷新';
      }
      if (key === 'edit_phone') {
        return '请在手机编辑任务';
      }
      if (key === 'needs_step') {
        return '请在手机拆分下一步';
      }
      if (key === 'flash') {
        return '闪念';
      }
      if (key === 'flash_hint') {
        return '先记下来，稍后再看';
      }
      if (key === 'title') {
        return '焦点锚';
      }
      if (key === 'add') {
        return '新建';
      }
      if (key === 'edit') {
        return '编辑';
      }
      if (key === 'save') {
        return '存';
      }
      if (key === 'cancel') {
        return '取消';
      }
      if (key === 'done') {
        return '完成';
      }
      if (key === 'delete') {
        return '删';
      }
      if (key === 'title_hint') {
        return '标题';
      }
      if (key === 'saved') {
        return '已保存';
      }
      return key;
    }
    if (key === 'home') {
      return 'Home';
    }
    if (key === 'tasks') {
      return 'Tasks';
    }
    if (key === 'focus') {
      return 'Focus';
    }
    if (key === 'sync_ok') {
      return 'OK';
    }
    if (key === 'sync_empty') {
      return 'Empty';
    }
    if (key === 'sync_fail') {
      return 'Offline';
    }
    if (key === 'sync_pending') {
      return 'Saved · pending';
    }
    if (key === 'sync_conflict') {
      return 'Step changed';
    }
    if (key === 'edit_phone') {
      return 'Edit on phone';
    }
    if (key === 'needs_step') {
      return 'Choose next step on phone';
    }
    if (key === 'flash') {
      return 'Quick note';
    }
    if (key === 'flash_hint') {
      return 'Save it for later';
    }
    if (key === 'title') {
      return 'Focus';
    }
    if (key === 'add') {
      return 'New';
    }
    if (key === 'edit') {
      return 'Edit';
    }
    if (key === 'save') {
      return 'OK';
    }
    if (key === 'cancel') {
      return 'Back';
    }
    if (key === 'done') {
      return 'Done';
    }
    if (key === 'delete') {
      return 'Del';
    }
    if (key === 'title_hint') {
      return 'Title';
    }
    if (key === 'saved') {
      return 'Saved';
    }
    return key;
  }

  private async initLocal(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.pref = await preferences.getPreferences(context, 'wear_focux');
      await this.loadLang();
      await this.loadLocalTasks();
      const rawEvents = await this.pref.get('pending_action_events', '[]');
      const parsed = JSON.parse(`${rawEvents}`) as WearActionEvent[];
      this.actionQueue = new WearSyncQueue(Array.isArray(parsed) ? parsed : []);
      const sequence = await this.pref.get('action_event_sequence', 1);
      this.actionSequence = typeof sequence === 'number' && sequence > 0 ? sequence : 1;
      const paused = await this.pref.get('paused_action_id', '');
      this.pausedActionId = typeof paused === 'string' ? paused : '';
      const flashRaw = await this.pref.get('pending_flash_notes', '[]');
      const flashParsed = JSON.parse(`${flashRaw}`) as WearFlashNote[];
      this.flashQueue = new WearFlashQueue(Array.isArray(flashParsed) ? flashParsed : []);
      this.flashPendingCount = this.flashQueue.pending().length;
      const flashSequence = await this.pref.get('flash_sequence', 1);
      this.flashSequence = typeof flashSequence === 'number' && flashSequence > 0 ? flashSequence : 1;
      const deviceId = await this.pref.get('flash_device_id', '');
      this.flashDeviceId = typeof deviceId === 'string' && deviceId ? deviceId :
        `wear_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
      if (!deviceId) {
        await this.pref.put('flash_device_id', this.flashDeviceId);
        await this.pref.flush();
      }
      if (this.flashPendingCount > 0) this.flashUiState = 'PENDING';
      if (this.actionQueue.pending().length > 0) {
        this.statusText = this.tx('sync_pending');
      }
    } catch (_e) {
      this.lang = 0;
    }
  }

  private async loadLang(): Promise<void> {
    if (!this.pref) {
      return;
    }
    const v = await this.pref.get('language', 0);
    this.lang = typeof v === 'number' ? (v === 1 ? 1 : 0) : 0;
  }

  private async loadLocalTasks(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      const stamp = await this.pref.get('tasks_stamp', 0);
      this.localStamp = typeof stamp === 'number' ? stamp : 0;
      const raw = await this.pref.get('tasks_json', '');
      if (typeof raw === 'string' && raw.length > 0) {
        const parsed = JSON.parse(raw) as WearTask[];
        if (Array.isArray(parsed)) {
          this.applyTaskList(parsed);
        }
      }
    } catch (_e) {
      // ignore
    }
  }

  private applyTaskList(list: WearTask[]): void {
    this.allTasks = list;
    this.tasks = list.filter((t: WearTask) => !t.completed);
  }

  private async initSync(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const kvManager = distributedKVStore.createKVManager({
        context: context,
        bundleName: context.abilityInfo.bundleName
      });
      const config: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: false,
        backup: false,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      };
      this.kvStore = await kvManager.getKVStore<distributedKVStore.SingleKVStore>('focux_watch_sync', config);
      this.syncUnavailable = false;
      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, () => {
        if (!this.writing) {
          this.reloadFromRemote();
        }
      });
      await this.reloadFromRemote();
      await this.flushActionQueue();
      await this.flushFlashQueue();
    } catch (error) {
      this.syncUnavailable = true;
      this.statusText = this.tx('sync_fail');
      if (this.flashQueue.pending().length > 0) this.flashUiState = 'SYNC_FAILED';
    }
  }

  private parseBundle(text: string): TaskSyncBundle {
    const parsed = JSON.parse(text) as Object;
    if (Array.isArray(parsed)) {
      return { updatedAt: 0, tasks: this.normalizeList(parsed as WearTask[]) };
    }
    const obj = parsed as TaskSyncBundle;
    const tasks = Array.isArray(obj.tasks) ? this.normalizeList(obj.tasks) : [];
    const updatedAt = typeof obj.updatedAt === 'number' ? obj.updatedAt : 0;
    const companionState = ['STABLE', 'FLUCTUATING', 'SUPPORT_REQUESTED'].includes(obj.companionState ?? '') ?
      obj.companionState : 'UNKNOWN';
    return { updatedAt, tasks, source: obj.source,
      currentActionId: typeof obj.currentActionId === 'string' ? obj.currentActionId : undefined,
      companionState: companionState };
  }

  private normalizeList(list: WearTask[]): WearTask[] {
    return list.map((t: WearTask) => this.normalizeTask(t));
  }

  private normalizeTask(t: WearTask): WearTask {
    const priority = t.priority === 1 || t.priority === 3 ? t.priority : 2;
    return {
      id: t.id && t.id.length > 0 ? t.id : `wear_${Date.now()}`,
      title: t.title ?? '',
      content: t.content ?? '',
      studyMinutes: typeof t.studyMinutes === 'number' ? t.studyMinutes : 25,
      studyMethod: t.studyMethod ?? 'reading',
      priority: priority,
      basePriority: typeof t.basePriority === 'number' ? t.basePriority : priority,
      completed: !!t.completed,
      createdAt: typeof t.createdAt === 'number' ? t.createdAt : Date.now(),
      dueAt: t.dueAt,
      insight: t.insight ?? '',
      focusStep: t.focusStep
    };
  }

  private async reloadFromRemote(): Promise<void> {
    if (!this.kvStore) {
      return;
    }
    try {
      const ackStatus = await this.consumeActionAcks();
      await this.consumeFlashAcks();
      const value = await this.kvStore.get('tasks_sync');
      let text = '';
      if (typeof value === 'string') {
        text = value;
      }
      if (text.length === 0) {
        this.statusText = ackStatus ?? (this.actionQueue.pending().length > 0 ? this.tx('sync_pending') :
          (this.tasks.length > 0 ? this.tx('sync_ok') : this.tx('sync_empty')));
        return;
      }
      const bundle = this.parseBundle(text);
      if (shouldAdoptPhoneProjection(bundle, this.localStamp)) {
        this.applyTaskList(bundle.tasks);
        this.currentActionId = bundle.currentActionId ?? '';
        this.companionState = bundle.companionState ?? 'UNKNOWN';
        if (this.pausedActionId && this.currentStepTask()?.focusStep?.actionId !== this.pausedActionId) {
          this.pausedActionId = '';
        }
        this.localStamp = bundle.updatedAt;
        await this.persistLocal(bundle.tasks, bundle.updatedAt);
        this.statusText = ackStatus ?? (this.actionQueue.pending().length > 0 ? this.tx('sync_pending') :
          (this.tasks.length > 0 ? this.tx('sync_ok') : this.tx('sync_empty')));
      }
      try {
        const langVal = await this.kvStore.get('language_sync');
        if (typeof langVal === 'number') {
          this.lang = langVal === 1 ? 1 : 0;
          if (this.pref) {
            await this.pref.put('language', this.lang);
            await this.pref.flush();
          }
        }
      } catch (_e) {
        // optional
      }
    } catch (error) {
      this.syncUnavailable = true;
      this.statusText = this.tx('sync_fail');
    }
  }

  private async saveActionQueue(): Promise<void> {
    if (!this.pref) {
      throw new Error('Watch local queue unavailable');
    }
    await this.pref.put('pending_action_events', JSON.stringify(this.actionQueue.pending()));
    await this.pref.put('action_event_sequence', this.actionSequence);
    await this.pref.flush();
  }

  private async flushActionQueue(): Promise<void> {
    await this.serializeActionMutation(async () => this.flushActionQueueNow());
  }

  private async flushActionQueueNow(): Promise<void> {
    if (!this.kvStore || this.actionQueue.pending().length === 0) {
      return;
    }
    try {
      await this.kvStore.put('action_events_sync', JSON.stringify(this.actionQueue.pending()));
      this.syncUnavailable = false;
    } catch (_e) {
      this.syncUnavailable = true;
      this.statusText = this.tx('sync_pending');
    }
  }

  private async consumeActionAcks(): Promise<string | undefined> {
    let status: string | undefined = undefined;
    await this.serializeActionMutation(async () => {
      status = await this.consumeActionAcksNow();
    });
    return status;
  }

  private async consumeActionAcksNow(): Promise<string | undefined> {
    if (!this.kvStore || this.actionQueue.pending().length === 0) {
      return undefined;
    }
    try {
      const raw = await this.kvStore.get('action_acks_sync');
      const parsed = typeof raw === 'string' ? JSON.parse(raw) as WearActionAck[] : [];
      if (!Array.isArray(parsed)) {
        return undefined;
      }
      let rejected = false;
      let needsStep = false;
      let consumed = false;
      for (const ack of parsed) {
        const pending = this.actionQueue.pending().find((event: WearActionEvent) => event.eventId === ack.eventId);
        if (pending) {
          consumed = true;
          rejected = rejected || (ack.status !== 'applied' && ack.status !== 'duplicate' &&
            ack.status !== 'session_only');
          needsStep = needsStep || ack.status === 'needs_step';
          if (ack.status === 'session_only') {
            if (pending.type === 'pause') {
              this.pausedActionId = pending.actionId;
            } else if (pending.type === 'resume') {
              this.pausedActionId = '';
            }
          }
          this.actionQueue.ack(ack.eventId);
        }
      }
      if (!consumed) {
        return undefined;
      }
      await this.saveActionQueue();
      if (this.pref) {
        await this.pref.put('paused_action_id', this.pausedActionId);
        await this.pref.flush();
      }
      this.statusText = needsStep ? this.tx('needs_step') : rejected ? this.tx('sync_conflict') :
        (this.actionQueue.pending().length > 0 ? this.tx('sync_pending') : this.tx('sync_ok'));
      return this.statusText;
    } catch (_e) {
      // Missing ack or offline: pending events remain durable.
      return undefined;
    }
  }

  private async serializeActionMutation(operation: () => Promise<void>): Promise<void> {
    const run = this.actionMutation.then(operation, operation);
    this.actionMutation = run.catch(() => {});
    await run;
  }

  private async saveFlashQueue(): Promise<void> {
    if (!this.pref) {
      throw new Error('Watch flash local storage unavailable');
    }
    await this.pref.put('pending_flash_notes', JSON.stringify(this.flashQueue.pending()));
    await this.pref.put('flash_sequence', this.flashSequence);
    await this.pref.put('flash_device_id', this.flashDeviceId);
    await this.pref.flush();
    this.flashPendingCount = this.flashQueue.pending().length;
  }

  private async serializeFlashMutation(operation: () => Promise<void>): Promise<void> {
    const run = this.flashMutation.then(operation, operation);
    this.flashMutation = run.catch(() => {});
    await run;
  }

  private async flushFlashQueue(): Promise<void> {
    await this.serializeFlashMutation(async () => this.flushFlashQueueNow());
  }

  private async retryFlashSync(): Promise<void> {
    if (this.kvStore) {
      await this.flushFlashQueue();
    } else {
      await this.initSync();
    }
  }

  private async flushFlashQueueNow(): Promise<void> {
    if (!this.kvStore || this.flashQueue.pending().length === 0) {
      return;
    }
    try {
      await this.kvStore.put('flash_notes_sync', JSON.stringify(this.flashQueue.pending()));
      this.flashUiState = flashTransportState(true);
    } catch (_e) {
      this.flashUiState = flashTransportState(false);
    }
  }

  private async consumeFlashAcks(): Promise<void> {
    await this.serializeFlashMutation(async () => {
      if (!this.kvStore || this.flashQueue.pending().length === 0) {
        return;
      }
      try {
        const raw = await this.kvStore.get('flash_acks_sync');
        const ids = typeof raw === 'string' ? JSON.parse(raw) as string[] : [];
        if (!Array.isArray(ids)) {
          return;
        }
        let changed = false;
        for (const id of ids) {
          if (this.flashQueue.pending().some((note: WearFlashNote) => note.flashId === id)) {
            this.flashQueue.ack(id);
            changed = true;
          }
        }
        if (changed) {
          await this.saveFlashQueue();
          this.flashUiState = this.flashQueue.pending().length > 0 ? 'PENDING' : 'SYNCED';
        }
      } catch (_e) {
        // The durable queue remains pending until a phone acknowledgement arrives.
      }
    });
  }

  private async saveFlashDraft(): Promise<void> {
    await this.serializeFlashMutation(async () => {
      const content = this.flashDraft.trim();
      if (!content || !this.pref || !this.flashDeviceId) {
        this.flashUiState = 'SAVE_FAILED';
        return;
      }
      const note: WearFlashNote = {
        flashId: flashIdForSequence(this.flashDeviceId, this.flashSequence),
        content: content,
        sourceDevice: 'watch',
        createdAt: Date.now(),
        syncStatus: 'pending'
      };
      this.flashQueue.enqueue(note);
      this.flashSequence += 1;
      try {
        await this.saveFlashQueue();
        this.flashDraft = '';
        this.flashEditing = false;
        this.flashUiState = 'LOCAL';
        await this.flushFlashQueueNow();
        if (this.flashUiState === 'LOCAL') this.flashUiState = 'PENDING';
      } catch (_e) {
        this.flashUiState = 'SAVE_FAILED';
      }
    });
  }

  private async persistLocal(list: WearTask[], stamp: number): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put('tasks_json', JSON.stringify(list));
      await this.pref.put('tasks_stamp', stamp);
      await this.pref.flush();
    } catch (_e) {
      // ignore
    }
  }

  private currentStepTask(): WearTask | undefined {
    return selectCurrentAction(this.tasks, this.currentActionId || undefined);
  }

  private async actOnCurrentStep(): Promise<void> {
    const current = this.currentStepTask();
    if (!current?.focusStep || current.focusStep.status === 'completed') {
      return;
    }
    const step = current.focusStep;
    const type = primaryStepEvent(step.status, this.pausedActionId === step.actionId);
    await this.sendStepEvent(type);
  }

  private async sendStepEvent(type: 'start' | 'resume' | 'pause' | 'complete' | 'change'): Promise<void> {
    await this.serializeActionMutation(async () => {
      const current = this.currentStepTask();
      if (!current?.focusStep) {
        return;
      }
      const step = current.focusStep;
      if (!step.actionId || !step.revision || !this.pref) {
        this.statusText = this.tx('sync_conflict');
        return;
      }
      const queued = this.actionQueue.enqueueOperation(current.id, step.actionId,
        step.revision, type, this.actionSequence, Date.now());
      this.actionSequence = queued.nextSequence;
      try {
        await this.saveActionQueue();
        this.statusText = this.tx('sync_pending');
        await this.flushActionQueueNow();
      } catch (_e) {
        this.statusText = this.tx('sync_fail');
      }
    });
  }

  private openFocus(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/FocusPage' }).catch(() => {
    });
  }

  private openFlashInput(): void {
    this.flashEditing = true;
    // Focus the existing system input immediately after the conditional field enters the tree.
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus('flashDraftInput');
      } catch (_e) {
        // The field remains available for a direct tap on devices without this focus path.
      }
    }, 80);
  }

  @Builder
  homePage() {
    Column({ space: 4 }) {
      Image(wearVisualResource(this.homeVisualId()))
        .width(88)
        .height(68)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F3F5F0')
        .borderRadius(18)
      if (this.currentStepTask()?.focusStep) {
        Text(this.currentStepTask()?.focusStep?.text ?? '')
          .fontSize(13)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')
        if (this.currentStepTask()?.focusStep?.generationSource === 'MOCK' ||
          this.currentStepTask()?.focusStep?.generationSource === 'RULE') {
          Text(this.currentStepTask()?.focusStep?.generationSource === 'MOCK' ?
            (this.lang === 1 ? '本地模拟步骤' : 'Local mock step') :
            (this.lang === 1 ? '规则生成步骤' : 'Rule step'))
            .fontSize(9)
            .fontColor('#B9C8BD')
        }
        if (this.showStepFeedback) {
          Row({ space: 6 }) {
            Button(this.lang === 1 ? '完成' : 'Done')
              .height(38)
              .layoutWeight(1)
              .onClick(() => { this.sendStepEvent('complete'); this.showStepFeedback = false; })
            Button(this.lang === 1 ? '换一步' : 'Change')
              .height(38)
              .layoutWeight(1)
              .onClick(() => { this.sendStepEvent('change'); this.showStepFeedback = false; })
          }
          .width('100%')
          Text(this.lang === 1 ? '返回主操作' : 'Back to main action')
            .fontSize(10)
            .fontColor('#B9C8BD')
            .height(22)
            .onClick(() => { this.showStepFeedback = false; })
        } else {
          Button(this.currentStepTask()?.focusStep?.status === 'in_progress' ?
            (this.pausedActionId === this.currentStepTask()?.focusStep?.actionId ?
              (this.lang === 1 ? '继续' : 'Resume') : (this.lang === 1 ? '暂停' : 'Pause')) :
            (this.lang === 1 ? '开始' : 'Start'))
            .width('100%')
            .height(40)
            .fontSize(14)
            .backgroundColor('#4A7C59')
            .onClick(() => this.actOnCurrentStep())
          Text(this.lang === 1 ? '完成 / 换一步 ···' : 'Complete / Change ···')
            .fontSize(10)
            .fontColor('#B9C8BD')
            .height(22)
            .onClick(() => { this.showStepFeedback = true; })
        }
      } else {
        Text(this.lang === 1 ? '暂无当前一步' : 'No current step')
          .fontSize(14)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text(this.companionState === 'UNKNOWN' ?
          (this.lang === 1 ? '状态未知 · 手机选择第一步' : 'State unknown · choose a step on phone') :
          companionStateLabel(this.companionState, this.lang === 1))
          .fontSize(9)
          .fontColor('#B9C8BD')
          .maxLines(1)
          .textAlign(TextAlign.Center)
      }
      Text(this.statusText)
        .fontSize(9)
        .fontColor('#B9C8BD')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.lang === 1 ? '心率监测 ›' : 'Heart rate ›')
        .fontSize(10)
        .fontColor('#A6D895')
        .height(24)
        .onClick(() => this.openFocus())
    }
    .width(this.contentW())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private homeVisualId(): string {
    const step = this.currentStepTask()?.focusStep;
    if (!step) return companionVisualId(this.companionState);
    if (step.status === 'in_progress') {
      return interactionVisualId(this.pausedActionId === step.actionId ? 'PAUSED' : 'IN_PROGRESS');
    }
    if (step.status === 'completed') return interactionVisualId('STEP_COMPLETE');
    return interactionVisualId('FIRST_STEP');
  }


  @Builder
  flashPage() {
    Column({ space: 4 }) {
      if (!this.flashEditing && this.flashUiState === 'IDLE') {
        Image($r('app.media.status_ready'))
          .width(52)
          .height(42)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#E8EFE6')
          .borderRadius(21)
      }
      Text(this.tx('flash'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
      if (this.flashEditing) {
        Image(wearVisualResource(interactionVisualId('LISTENING')))
          .width(88)
          .height(66)
          .objectFit(ImageFit.Contain)
        TextInput({ text: this.flashDraft, placeholder: this.tx('flash_hint') })
          .id('flashDraftInput')
          .defaultFocus(true)
          .width('100%')
          .height(42)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor('#36503D')
          .borderRadius(20)
          .onChange((value: string) => { this.flashDraft = value; })
        Text(this.lang === 1 ? '可用系统键盘的麦克风输入' : 'Use the system keyboard microphone')
          .fontSize(9)
          .fontColor('#B9C8BD')
          .maxLines(2)
          .textAlign(TextAlign.Center)
        Row({ space: 8 }) {
          Button(this.tx('save'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#4A7C59')
            .onClick(() => this.saveFlashDraft())
          Button(this.tx('cancel'))
            .layoutWeight(1)
            .height(40)
            .onClick(() => { this.flashEditing = false; this.flashDraft = ''; })
        }
        .width('100%')
      } else {
        Button(this.lang === 1 ? '语音记闪念' : 'Voice quick note')
          .width('100%')
          .height(46)
          .fontSize(14)
          .backgroundColor('#4A7C59')
          .onClick(() => this.openFlashInput())
        if (this.flashUiState === 'IDLE') {
          Text(this.lang === 1 ? '使用系统输入法，也可打字' : 'System keyboard · typing available')
            .fontSize(9)
            .fontColor('#B9C8BD')
            .textAlign(TextAlign.Center)
        }
      }
      Text(flashUiLabel(this.flashUiState, this.lang === 1))
        .fontSize(10)
        .fontColor(this.flashUiState === 'SAVE_FAILED' || this.flashUiState === 'SYNC_FAILED' ?
          '#F0B184' : '#A6D895')
        .maxLines(2)
        .textAlign(TextAlign.Center)
      if (this.flashUiState === 'SYNC_FAILED') {
        Button(this.lang === 1 ? '重试同步' : 'Retry sync')
          .height(36)
          .onClick(() => this.retryFlashSync())
      }
    }
    .width(this.contentW())
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  pageDots() {
    Row({ space: 8 }) {
      Button(this.lang === 1 ? '当前一步' : 'Step')
        .height(36)
        .layoutWeight(1)
        .fontSize(11)
        .backgroundColor(this.currentIndex === 0 ? '#4A7C59' : '#36503D')
        .onClick(() => {
          this.currentIndex = 0;
          this.swiperController.changeIndex(0, true);
        })
      Button(this.lang === 1 ? '闪念' : 'Note')
        .height(36)
        .layoutWeight(1)
        .fontSize(11)
        .backgroundColor(this.currentIndex === 1 ? '#4A7C59' : '#36503D')
        .onClick(() => {
          this.currentIndex = 1;
          this.swiperController.changeIndex(1, true);
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(38)
  }

  build() {
    Column({ space: 2 }) {
      Swiper(this.swiperController) {
        Column() {
          this.homePage()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column() {
          this.flashPage()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .index(this.currentIndex)
      .indicator(false)
      .loop(false)
      .vertical(false)
      .onChange((index: number) => {
        this.currentIndex = index;
        this.reloadFromRemote();
      })

      this.pageDots()
    }
    .width('100%')
    .height('100%')
    .padding({
      left: SAFE_H,
      right: SAFE_H,
      top: Math.max(10, SAFE_V_TOP - 8),
      bottom: SAFE_V_BOT
    })
    .backgroundColor('#202420')
    .onAreaChange((_o: Area, area: Area) => {
      const w = Number(area.width);
      const h = Number(area.height);
      const side = Math.min(
        Number.isNaN(w) ? 200 : w,
        Number.isNaN(h) ? 200 : h
      );
      if (side > 0) {
        this.pageSize = side;
      }
    })
  }
}
