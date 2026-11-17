import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { StudyTask } from '../models/AppTypes';
import { sortTasks } from './StorageService';

const TASK_FILE: string = 'tasks.json';

export class TaskFileService {
  private static instance: TaskFileService | undefined;
  private filePath: string = '';

  static getInstance(): TaskFileService {
    if (!TaskFileService.instance) {
      TaskFileService.instance = new TaskFileService();
    }
    return TaskFileService.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.filePath = `${context.filesDir}/${TASK_FILE}`;
  }

  async loadTasks(): Promise<StudyTask[]> {
    if (!this.filePath) {
      return [];
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
      return sortTasks(Array.isArray(parsed) ? parsed : []);
    } catch (error) {
      return [];
    }
  }

  async saveTasks(tasks: StudyTask[]): Promise<void> {
    if (!this.filePath) {
      return;
    }
    const payload = JSON.stringify(sortTasks(tasks));
    const file = fs.openSync(this.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    const bytes = new util.TextEncoder().encodeInto(payload);
    fs.writeSync(file.fd, bytes.buffer);
    fs.closeSync(file);
  }
}
