import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { StudyTask } from '../models/AppTypes';
import { sortTasks } from './StorageService';
import { materializeTaskAction } from './ActionLogic';

const TASK_FILE: string = 'tasks.json';

export class TaskFileService {
  private static instance: TaskFileService | undefined;
  private static writeTail: Promise<void> = Promise.resolve();
  private filePath: string = '';

  static getInstance(): TaskFileService {
    if (!TaskFileService.instance) {
      TaskFileService.instance = new TaskFileService();
    }
    return TaskFileService.instance;
  }

  init(context: common.Context): void {
    this.filePath = `${context.filesDir}/${TASK_FILE}`;
  }

  /** Serialize read-modify-write transactions from phone, card, and watch callbacks. */
  async withExclusive<T>(work: () => Promise<T>): Promise<T> {
    const previous = TaskFileService.writeTail;
    let unlock: () => void = () => {};
    TaskFileService.writeTail = new Promise<void>((resolve: () => void) => {
      unlock = resolve;
    });
    await previous;
    try {
      return await work();
    } finally {
      unlock();
    }
  }

  async loadTasks(): Promise<StudyTask[]> {
    if (!this.filePath) {
      throw new Error('TaskFileService not initialized');
    }
    try {
      if (!fs.accessSync(this.filePath)) {
        await this.saveTasks([]);
        return [];
      }
      const file = fs.openSync(this.filePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(this.filePath);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text = new util.TextDecoder().decodeToString(new Uint8Array(buf));
      if (!text || text.length === 0) {
        return [];
      }
      const parsed = JSON.parse(text) as StudyTask[];
      const tasks = sortTasks(Array.isArray(parsed) ? parsed : []);
      let migrated = false;
      const normalized = tasks.map((task: StudyTask): StudyTask => {
        const next = materializeTaskAction(task);
        if (next !== task) {
          migrated = true;
        }
        return next;
      });
      if (migrated) {
        await this.saveTasks(normalized);
      }
      return normalized;
    } catch (error) {
      throw new Error('Task file read failed');
    }
  }

  async saveTasks(tasks: StudyTask[]): Promise<void> {
    if (!this.filePath) {
      throw new Error('TaskFileService not initialized');
    }
    const payload = JSON.stringify(sortTasks(tasks.map((task: StudyTask) => materializeTaskAction(task))));
    const file = fs.openSync(this.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    const bytes = new util.TextEncoder().encodeInto(payload);
    fs.writeSync(file.fd, bytes.buffer);
    fs.closeSync(file);
  }
}
