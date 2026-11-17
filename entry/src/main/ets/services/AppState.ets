import { common } from '@kit.AbilityKit';
import {
  AppDataBundle,
  AppSettings,
  effectivePriorityNearDeadline,
  HeartRateSnapshot,
  StudyTask,
  FlashNote
} from '../models/AppTypes';
import { FocusStepStatus } from '../models/AppTypes';
import { AdviceService, HeartRateService } from './DomainServices';
import { createTaskId, sortTasks, StorageService } from './StorageService';
import { TaskFileService } from './TaskFileService';
import { WatchSyncService } from './WatchSyncService';
import { ReminderService } from './ReminderService';
import { XiaoyiBridge } from './XiaoyiBridge';
import { FocusCardService } from './FocusCardService';
import { ActionEventService } from './ActionEventService';
import { normalizeFocusAction } from './ActionLogic';
import { FocusSessionService } from './FocusSessionService';
import { FlashNoteService } from './FlashNoteService';
import { flashTaskId } from './FlashNoteLogic';
import { WorkflowV21AppService } from './WorkflowV21AppService';
import { ConfirmationChoice, WorkflowResult } from './WorkflowV21Contracts';

export class AppState {
  private static instance: AppState | undefined;
  private storage: StorageService = StorageService.getInstance();
  private taskFile: TaskFileService = TaskFileService.getInstance();
  private flashFile: FlashNoteService = FlashNoteService.getInstance();
  private watchSync: WatchSyncService = WatchSyncService.getInstance();
  private heartRateService: HeartRateService = new HeartRateService();
  private adviceService: AdviceService = new AdviceService();
  private unlockedPin: string = 'focus-anchor-default';
  private context: common.UIAbilityContext | undefined;
  private workflowV21: WorkflowV21AppService | undefined;
  tasks: StudyTask[] = [];
  flashNotes: FlashNote[] = [];
  dataError: string = '';
  heartRateHistory: HeartRateSnapshot[] = [];
  settings: AppSettings = {
    hrMin: 60,
    hrMax: 120,
    pinEnabled: false,
    pinHash: '',
    userName: 'Learner',
    age: 18,
    language: 0,
    avatar: 'anchor',
    avatarUri: '',
    privacy: {
      shareUsageData: false,
      allowAnalytics: false,
      showAgeOnProfile: false,
      localEncryptionOnly: true
    }
  };
  latestHeartRate: HeartRateSnapshot | undefined = undefined;
  monitoring: boolean = false;
  /** Last task-sync timestamp used for watch merge */
  taskSyncStamp: number = 0;
  /** Token bumped when float ball requests opening the add-task editor */
  openEditorToken: number = 0;

  static getInstance(): AppState {
    if (!AppState.instance) {
      AppState.instance = new AppState();
    }
    return AppState.instance;
  }

  async bootstrap(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    await this.storage.init(context);
    this.taskFile.init(context);
    this.flashFile.init(context);
    this.flashNotes = await this.flashFile.load();
    await XiaoyiBridge.getInstance().init(context);
    await this.watchSync.init(context);
    const bundle = await this.storage.loadBundle(this.unlockedPin);
    this.heartRateHistory = bundle.heartRateHistory;
    this.settings = bundle.settings;
    // Dedicated language key wins over any stale encrypted settings.language
    const storedLang = await this.storage.loadLanguage();
    this.settings.language = storedLang;
    const fileTasks = await this.taskFile.loadTasks();
    if (fileTasks.length > 0) {
      this.tasks = sortTasks(fileTasks);
    } else if (bundle.tasks.length > 0) {
      this.tasks = sortTasks(bundle.tasks);
      await this.taskFile.saveTasks(this.tasks);
    } else {
      this.tasks = [];
    }
    try {
      await this.recoverWorkflowV21();
    } catch (_) {
      this.dataError = 'Local workflow recovery failed; existing tasks were retained.';
    }
    await this.refreshDeadlinePriorities();
    if (this.heartRateHistory.length > 0) {
      this.latestHeartRate = this.heartRateHistory[this.heartRateHistory.length - 1];
    }
    // Phone task file owns Action state; the watch receives projections only.
    await this.watchSync.pushTasksToWatch(this.tasks);
    this.taskSyncStamp = Date.now();
    await this.watchSync.pushLanguage(this.settings.language ?? 0);
    await FocusCardService.refresh(context, this.tasks);
    await this.watchSync.startActionListening(async (event) => {
      const result = await ActionEventService.apply(context, event);
      await this.reloadTasksFromDisk();
      await this.watchSync.pushTasksToWatch(this.tasks);
      return result;
    });
    await this.watchSync.startFlashListening(async (notes: FlashNote[]) => {
      this.flashNotes = await this.flashFile.ingest(notes);
    });
    ReminderService.getInstance().startPeriodicCheck(() => this.getPendingTasks());
  }

  /** Incomplete tasks only, sorted for the visible list. */
  getPendingTasks(): StudyTask[] {
    return sortTasks(this.tasks.filter((task: StudyTask) => !task.completed));
  }

  /** Reload tasks from local tasks.json so the UI always reflects persisted data. */
  async reloadTasksFromDisk(): Promise<void> {
    const fileTasks = await this.taskFile.loadTasks();
    this.tasks = sortTasks(fileTasks);
    await this.refreshDeadlinePriorities();
  }

  /** Near deadline → raise urgency by one level; persist if changed. */
  async refreshDeadlinePriorities(): Promise<boolean> {
    const now = Date.now();
    let changed = false;
    this.tasks = this.tasks.map((task: StudyTask) => {
      const base = task.basePriority ?? task.priority;
      const next = effectivePriorityNearDeadline(task, now);
      if (task.basePriority === undefined || task.priority !== next) {
        changed = true;
        return {
          id: task.id,
          title: task.title,
          content: task.content,
          studyMinutes: task.studyMinutes,
          studyMethod: task.studyMethod,
          priority: next,
          basePriority: base,
          completed: task.completed,
          createdAt: task.createdAt,
          dueAt: task.dueAt,
          insight: task.insight,
          focusStep: task.focusStep
        };
      }
      return task;
    });
    if (changed) {
      this.tasks = sortTasks(this.tasks);
      await this.persist();
    }
    return changed;
  }

  /** Remove task from local list and tasks.json. */
  async clearTask(taskId: string): Promise<void> {
    await this.removeTask(taskId);
  }

  async persist(localOnly: boolean = false): Promise<void> {
    // FormExtensionAbility can write a newer step while the UIAbility is in memory.
    await this.taskFile.withExclusive(async (): Promise<void> => {
      const onDisk = await this.taskFile.loadTasks();
      if (localOnly) {
        // The V2.1 bridge already committed tasks.json. Re-read it under the lock so
        // persisting the bundle cannot remove a concurrent task or Action update.
        this.tasks = sortTasks(onDisk);
        const localBundle: AppDataBundle = {
          tasks: this.tasks,
          heartRateHistory: this.heartRateHistory.slice(-50),
          settings: this.settings
        };
        await this.storage.saveBundle(localBundle, this.unlockedPin);
        return;
      }
      this.tasks = this.tasks.map((task: StudyTask) => {
        const diskStep = onDisk.find((item: StudyTask) => item.id === task.id)?.focusStep;
        if (diskStep && diskStep.updatedAt > (task.focusStep?.updatedAt ?? 0)) {
          task.focusStep = diskStep;
        }
        return task;
      });
      await this.taskFile.saveTasks(this.tasks);
      const bundle: AppDataBundle = {
        tasks: this.tasks,
        heartRateHistory: this.heartRateHistory.slice(-50),
        settings: this.settings
      };
      await this.storage.saveBundle(bundle, this.unlockedPin);
      await this.watchSync.pushTasksToWatch(this.tasks);
      this.taskSyncStamp = Date.now();
      await this.watchSync.pushLanguage(this.settings.language ?? 0);
      if (this.context) {
        await FocusCardService.refresh(this.context, this.tasks);
      }
    });
  }

  /** Explicit opt-in entry point; bootstrap does not instantiate or run the V2.1 mocks. */
  async proposeWorkflowV21(title: string, text: string, taskId?: string): Promise<WorkflowResult> {
    const service = this.getWorkflowV21();
    if (!service) {
      return { status: 'BLOCKED', reason: this.context ? 'CONSENT_REQUIRED_OR_REVOKED' : 'APP_NOT_READY' };
    }
    return service.propose(title, text, taskId);
  }

  async confirmWorkflowV21(planId: string, revision: number, choice: ConfirmationChoice, edit?: string): Promise<WorkflowResult> {
    const service = this.getWorkflowV21();
    if (!service) {
      return { status: 'BLOCKED', reason: this.context ? 'CONSENT_REQUIRED_OR_REVOKED' : 'APP_NOT_READY' };
    }
    const result = await service.confirm(planId, revision, choice, edit);
    if (result.status === 'LOCAL_CONFIRMED') {
      // Avoid reloadTasksFromDisk's deadline refresh, which can publish to the real watch.
      this.tasks = sortTasks(await this.taskFile.loadTasks());
      await this.persist(true);
    }
    return result;
  }

  async recoverWorkflowV21(): Promise<boolean> {
    const service = this.getWorkflowV21();
    if (!service || !(await service.restoreProjection())) {
      return false;
    }
    this.tasks = sortTasks(await this.taskFile.loadTasks());
    await this.persist(true);
    return true;
  }

  private getWorkflowV21(): WorkflowV21AppService | undefined {
    if (!this.context || this.settings.privacy?.consentFocusSupport !== true) {
      return undefined;
    }
    if (!this.workflowV21) {
      this.workflowV21 = new WorkflowV21AppService(this.context, this.taskFile,
        (): boolean => this.settings.privacy?.consentFocusSupport === true,
        (): number => this.settings.privacy?.workflowConsentVersion ?? 1);
    }
    return this.workflowV21;
  }

  /** Confirm the workflow's proposed first step as part of the canonical task. */
  async confirmGuidedStep(taskId: string, title: string, text: string): Promise<string> {
    let task = this.tasks.find((item: StudyTask) => item.id === taskId);
    if (!task) {
      task = this.tasks.find((item: StudyTask) => !item.completed && item.title === title);
    }
    if (!task) {
      task = this.createBlankTask();
      task.title = title;
      this.tasks = [...this.tasks, task];
    }
    const now = Date.now();
    task.focusStep = {
      taskId: task.id,
      actionId: `action_${encodeURIComponent(task.id)}_${now}`,
      text: text.trim(),
      status: 'ready',
      order: (task.focusStep?.order ?? -1) + 1,
      updatedAt: now,
      revision: 1,
      generationSource: 'rule'
    };
    this.tasks = sortTasks([...this.tasks]);
    await this.persist();
    return task.id;
  }

  /** Apply a guided action to the same task used by the card and watch. */
  async setGuidedStepStatus(taskId: string, status: FocusStepStatus): Promise<void> {
    const task = this.tasks.find((item: StudyTask) => item.id === taskId);
    if (!task || !task.focusStep) {
      return;
    }
    const action = normalizeFocusAction(task);
    if (!action || !this.context) {
      return;
    }
    if (status === 'paused') {
      await FocusSessionService.transition(this.context, taskId, action.actionId, 'pause');
      return;
    }
    if (status === 'in_progress' && action.status === 'in_progress') {
      await FocusSessionService.transition(this.context, taskId, action.actionId, 'resume');
      return;
    }
    const type = status === 'completed' ? 'complete' : 'start';
    const result = await ActionEventService.apply(this.context, {
      eventId: `phone_${action.actionId}_${action.revision}_${type}_${Date.now()}`,
      taskId,
      actionId: action.actionId,
      baseRevision: action.revision,
      type,
      origin: 'phone',
      createdAt: Date.now()
    });
    if (result.status === 'applied') {
      if (type === 'complete') {
        await FocusSessionService.finish(this.context, taskId, action.actionId);
      } else {
        await FocusSessionService.transition(this.context, taskId, action.actionId, 'start');
      }
    }
    await this.reloadTasksFromDisk();
  }

  getAdvice() {
    return this.adviceService.buildAdvice(this.latestHeartRate, this.tasks);
  }

  getEfficiencyScore(): number {
    return this.adviceService.efficiencyScore(this.latestHeartRate, this.tasks);
  }

  startMonitoring(onSample?: (snapshot: HeartRateSnapshot) => void): void {
    this.monitoring = true;
    this.heartRateService.start(async (snapshot: HeartRateSnapshot) => {
      this.latestHeartRate = snapshot;
      this.heartRateHistory.push(snapshot);
      await this.persist();
      if (onSample) {
        onSample(snapshot);
      }
    }, this.settings);
  }

  stopMonitoring(): void {
    this.monitoring = false;
    this.heartRateService.stop();
  }

  async addTask(task: StudyTask): Promise<void> {
    this.tasks = sortTasks([...this.tasks, task]);
    await this.persist();
  }

  /** Repeated conversion uses the same task ID, even if the first note update failed. */
  async convertFlashToTask(flashId: string): Promise<string | undefined> {
    if (!this.context) {
      return undefined;
    }
    this.flashNotes = await this.flashFile.load();
    const note = this.flashNotes.find((item: FlashNote) => item.flashId === flashId && !item.archived);
    if (!note) {
      return undefined;
    }
    const taskId = flashTaskId(flashId);
    let created = false;
    await this.taskFile.withExclusive(async (): Promise<void> => {
      const onDisk = await this.taskFile.loadTasks();
      if (onDisk.some((item: StudyTask) => item.id === taskId)) {
        return;
      }
      const task = this.createBlankTask();
      task.id = taskId;
      task.title = note.content;
      task.content = note.content;
      await this.taskFile.saveTasks([...onDisk, task]);
      created = true;
    });
    await this.flashFile.markConverted(flashId, taskId);
    this.flashNotes = await this.flashFile.load();
    if (created) {
      await this.reloadTasksFromDisk();
      await this.persist();
    }
    return taskId;
  }

  async archiveFlash(flashId: string): Promise<void> {
    await this.flashFile.archive(flashId);
    this.flashNotes = await this.flashFile.load();
  }

  /** Float ball / external UI asks TASK tab to open the add editor. */
  requestOpenEditor(): void {
    this.openEditorToken = Date.now();
  }

  /** Returns true once if a pending open-editor request exists. */
  consumeOpenEditor(): boolean {
    if (this.openEditorToken <= 0) {
      return false;
    }
    this.openEditorToken = 0;
    return true;
  }

  async updateTask(task: StudyTask): Promise<void> {
    this.tasks = sortTasks(this.tasks.map((item: StudyTask) => item.id === task.id ? task : item));
    await this.persist();
  }

  async toggleTask(taskId: string): Promise<void> {
    this.tasks = sortTasks(this.tasks.map((task: StudyTask) => {
      if (task.id === taskId) {
        const updated: StudyTask = {
          id: task.id,
          title: task.title,
          content: task.content,
          studyMinutes: task.studyMinutes,
          studyMethod: task.studyMethod,
          priority: task.priority,
          basePriority: task.basePriority ?? task.priority,
          completed: !task.completed,
          createdAt: task.createdAt,
          dueAt: task.dueAt,
          insight: task.insight,
          focusStep: task.focusStep
        };
        return updated;
      }
      return task;
    }));
    await this.persist();
  }

  shouldAlert(snapshot: HeartRateSnapshot): boolean {
    return this.heartRateService.shouldAlert(snapshot, this.settings);
  }

  async removeTask(taskId: string): Promise<void> {
    this.tasks = this.tasks.filter((task: StudyTask) => task.id !== taskId);
    await this.persist();
  }

  async updateSettings(settings: AppSettings, pin: string): Promise<void> {
    const previous = this.settings.privacy;
    const changed = previous.consentFocusSupport !== settings.privacy.consentFocusSupport ||
      previous.consentThoughtSandbox !== settings.privacy.consentThoughtSandbox;
    settings.privacy.workflowConsentVersion = (previous.workflowConsentVersion ?? 1) + (changed ? 1 : 0);
    this.settings = settings;
    this.unlockedPin = pin || this.unlockedPin;
    await this.storage.saveSettings(settings);
    await this.persist();
  }

  async manualHeartRate(bpm: number): Promise<HeartRateSnapshot> {
    const snapshot = this.heartRateService.manualSample(bpm, this.settings);
    this.latestHeartRate = snapshot;
    this.heartRateHistory.push(snapshot);
    await this.persist();
    return snapshot;
  }

  async applyBpm(bpm: number): Promise<HeartRateSnapshot> {
    return this.manualHeartRate(bpm);
  }

  createBlankTask(): StudyTask {
    return {
      id: createTaskId(),
      title: '',
      content: '',
      studyMinutes: 25,
      studyMethod: 'reading',
      priority: 2,
      basePriority: 2,
      completed: false,
      createdAt: Date.now(),
      dueAt: Date.now() + 24 * 60 * 60 * 1000,
      insight: ''
    };
  }
}
