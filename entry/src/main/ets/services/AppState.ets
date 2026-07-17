import { common } from '@kit.AbilityKit';
import {
  AppDataBundle,
  AppSettings,
  effectivePriorityNearDeadline,
  HeartRateSnapshot,
  StudyTask
} from '../models/AppTypes';
import { AdviceService, HeartRateService } from './DomainServices';
import { createTaskId, sortTasks, StorageService } from './StorageService';
import { TaskFileService } from './TaskFileService';
import { WatchSyncService } from './WatchSyncService';
import { ReminderService } from './ReminderService';
import { XiaoyiBridge } from './XiaoyiBridge';

export class AppState {
  private static instance: AppState | undefined;
  private storage: StorageService = StorageService.getInstance();
  private taskFile: TaskFileService = TaskFileService.getInstance();
  private watchSync: WatchSyncService = WatchSyncService.getInstance();
  private heartRateService: HeartRateService = new HeartRateService();
  private adviceService: AdviceService = new AdviceService();
  private unlockedPin: string = 'focus-anchor-default';
  private context: common.UIAbilityContext | undefined;
  tasks: StudyTask[] = [];
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
    await this.refreshDeadlinePriorities();
    if (this.heartRateHistory.length > 0) {
      this.latestHeartRate = this.heartRateHistory[this.heartRateHistory.length - 1];
    }
    // Adopt watch edits when remote bundle is newer
    const remoteTasks = await this.watchSync.pullIfNewer(this.taskSyncStamp);
    if (remoteTasks !== undefined) {
      this.tasks = remoteTasks;
      const remote = await this.watchSync.pullBundle();
      this.taskSyncStamp = remote?.updatedAt ?? Date.now();
      await this.taskFile.saveTasks(this.tasks);
    } else {
      await this.watchSync.pushTasksToWatch(this.tasks);
      this.taskSyncStamp = Date.now();
    }
    await this.watchSync.pushLanguage(this.settings.language ?? 0);
    this.watchSync.startListening(async (tasks: StudyTask[]) => {
      this.tasks = sortTasks(tasks);
      const remote = await this.watchSync.pullBundle();
      this.taskSyncStamp = remote?.updatedAt ?? Date.now();
      await this.taskFile.saveTasks(this.tasks);
      await this.storage.saveBundle({
        tasks: this.tasks,
        heartRateHistory: this.heartRateHistory.slice(-50),
        settings: this.settings
      }, this.unlockedPin);
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
          insight: task.insight
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

  async persist(): Promise<void> {
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
          insight: task.insight
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
