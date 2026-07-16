import { common } from '@kit.AbilityKit';
import { AppDataBundle, AppSettings, HeartRateSnapshot, StudyTask } from '../models/AppTypes';
import { AdviceService, HeartRateService } from './DomainServices';
import { createTaskId, sortTasks, StorageService } from './StorageService';

export class AppState {
  private static instance: AppState | undefined;
  private storage: StorageService = StorageService.getInstance();
  private heartRateService: HeartRateService = new HeartRateService();
  private adviceService: AdviceService = new AdviceService();
  private unlockedPin: string = 'focus-anchor-default';
  tasks: StudyTask[] = [];
  heartRateHistory: HeartRateSnapshot[] = [];
  settings: AppSettings = {
    hrMin: 60,
    hrMax: 100,
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

  static getInstance(): AppState {
    if (!AppState.instance) {
      AppState.instance = new AppState();
    }
    return AppState.instance;
  }

  async bootstrap(context: common.UIAbilityContext): Promise<void> {
    await this.storage.init(context);
    const bundle = await this.storage.loadBundle(this.unlockedPin);
    this.tasks = sortTasks(bundle.tasks);
    this.heartRateHistory = bundle.heartRateHistory;
    this.settings = bundle.settings;
    if (this.heartRateHistory.length > 0) {
      this.latestHeartRate = this.heartRateHistory[this.heartRateHistory.length - 1];
    }
  }

  async persist(): Promise<void> {
    const bundle: AppDataBundle = {
      tasks: this.tasks,
      heartRateHistory: this.heartRateHistory.slice(-50),
      settings: this.settings
    };
    await this.storage.saveBundle(bundle, this.unlockedPin);
  }

  getAdvice() {
    return this.adviceService.buildAdvice(this.latestHeartRate, this.tasks);
  }

  getEfficiencyScore(): number {
    return this.adviceService.efficiencyScore(this.latestHeartRate, this.tasks);
  }

  startMonitoring(onAlert: (snapshot: HeartRateSnapshot) => void): void {
    this.monitoring = true;
    this.heartRateService.start(async (snapshot: HeartRateSnapshot) => {
      this.latestHeartRate = snapshot;
      this.heartRateHistory.push(snapshot);
      await this.persist();
      if (this.heartRateService.shouldAlert(snapshot, this.settings)) {
        onAlert(snapshot);
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
          completed: !task.completed,
          createdAt: task.createdAt,
          dueAt: task.dueAt
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

  createBlankTask(): StudyTask {
    return {
      id: createTaskId(),
      title: '',
      content: '',
      studyMinutes: 25,
      studyMethod: 'reading',
      priority: 2,
      completed: false,
      createdAt: Date.now()
    };
  }
}
