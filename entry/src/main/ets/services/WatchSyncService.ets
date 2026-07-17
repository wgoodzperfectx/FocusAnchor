import { common } from '@kit.AbilityKit';
import { distributedKVStore } from '@kit.ArkData';
import { StudyTask } from '../models/AppTypes';
import { sortTasks } from './StorageService';

const STORE_ID: string = 'focux_watch_sync';
const TASKS_KEY: string = 'tasks_sync';
const LANG_KEY: string = 'language_sync';

export interface TaskSyncBundle {
  updatedAt: number;
  tasks: StudyTask[];
}

/**
 * Phone ↔ watch task sync via distributed KV (last-write-wins by updatedAt).
 */
export class WatchSyncService {
  private static instance: WatchSyncService | undefined;
  private kvStore: distributedKVStore.SingleKVStore | undefined;
  private ready: boolean = false;
  private lastPushedAt: number = 0;
  private applyingRemote: boolean = false;

  static getInstance(): WatchSyncService {
    if (!WatchSyncService.instance) {
      WatchSyncService.instance = new WatchSyncService();
    }
    return WatchSyncService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
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
      this.kvStore = await kvManager.getKVStore<distributedKVStore.SingleKVStore>(STORE_ID, config);
      this.ready = true;
    } catch (error) {
      this.ready = false;
      console.error('WatchSync init failed, local-only mode');
    }
  }

  /** Listen for watch-side edits and apply when remote is newer. */
  startListening(onRemoteTasks: (tasks: StudyTask[]) => void): void {
    if (!this.ready || !this.kvStore) {
      return;
    }
    this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, async () => {
      if (this.applyingRemote) {
        return;
      }
      const remote = await this.pullBundle();
      if (!remote) {
        return;
      }
      if (remote.updatedAt > this.lastPushedAt) {
        this.applyingRemote = true;
        try {
          onRemoteTasks(sortTasks(remote.tasks));
          this.lastPushedAt = remote.updatedAt;
        } finally {
          this.applyingRemote = false;
        }
      }
    });
  }

  async pullBundle(): Promise<TaskSyncBundle | undefined> {
    if (!this.ready || !this.kvStore) {
      return undefined;
    }
    try {
      const value = await this.kvStore.get(TASKS_KEY);
      if (typeof value !== 'string' || value.length === 0) {
        return undefined;
      }
      return this.parseBundle(value);
    } catch (error) {
      return undefined;
    }
  }

  private parseBundle(text: string): TaskSyncBundle {
    const parsed = JSON.parse(text) as Object;
    if (Array.isArray(parsed)) {
      return { updatedAt: 0, tasks: parsed as StudyTask[] };
    }
    const obj = parsed as TaskSyncBundle;
    const tasks = Array.isArray(obj.tasks) ? obj.tasks : [];
    const updatedAt = typeof obj.updatedAt === 'number' ? obj.updatedAt : 0;
    return { updatedAt, tasks };
  }

  /** Push tasks from phone (or after local edit). */
  async pushTasksToWatch(tasks: StudyTask[]): Promise<void> {
    if (!this.ready || !this.kvStore || this.applyingRemote) {
      return;
    }
    try {
      const updatedAt = Date.now();
      const bundle: TaskSyncBundle = { updatedAt, tasks };
      await this.kvStore.put(TASKS_KEY, JSON.stringify(bundle));
      this.lastPushedAt = updatedAt;
    } catch (error) {
      console.error('WatchSync push failed');
    }
  }

  /**
   * If remote bundle is newer than localStamp, return its tasks for AppState to adopt.
   */
  async pullIfNewer(localStamp: number): Promise<StudyTask[] | undefined> {
    const remote = await this.pullBundle();
    if (!remote) {
      return undefined;
    }
    if (remote.updatedAt > localStamp) {
      this.lastPushedAt = remote.updatedAt;
      return sortTasks(remote.tasks);
    }
    return undefined;
  }

  async pushLanguage(language: number): Promise<void> {
    if (!this.ready || !this.kvStore) {
      return;
    }
    try {
      await this.kvStore.put(LANG_KEY, language === 1 ? 1 : 0);
    } catch (error) {
      console.error('WatchSync language push failed');
    }
  }
}
