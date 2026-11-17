import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { FlashNote } from '../models/AppTypes';
import { archiveFlash, markFlashConverted, mergeFlashNotes } from './FlashNoteLogic';

const FILE_NAME: string = 'flash_notes.json';

/** Phone inbox; Action state is never touched by an incoming FlashNote. */
export class FlashNoteService {
  private static instance: FlashNoteService | undefined;
  private static writeTail: Promise<void> = Promise.resolve();
  private filePath: string = '';

  static getInstance(): FlashNoteService {
    if (!FlashNoteService.instance) {
      FlashNoteService.instance = new FlashNoteService();
    }
    return FlashNoteService.instance;
  }

  init(context: common.Context): void {
    this.filePath = `${context.filesDir}/${FILE_NAME}`;
  }

  private async withExclusive<T>(work: () => Promise<T>): Promise<T> {
    const previous = FlashNoteService.writeTail;
    let unlock: () => void = () => {};
    FlashNoteService.writeTail = new Promise<void>((resolve: () => void) => { unlock = resolve; });
    await previous;
    try {
      return await work();
    } finally {
      unlock();
    }
  }

  async load(): Promise<FlashNote[]> {
    if (!this.filePath || !fs.accessSync(this.filePath)) {
      return [];
    }
    const file = fs.openSync(this.filePath, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(this.filePath);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      const raw = new util.TextDecoder().decodeToString(new Uint8Array(buf));
      const parsed = JSON.parse(raw) as FlashNote[];
      return Array.isArray(parsed) ? parsed : [];
    } finally {
      fs.closeSync(file);
    }
  }

  async save(notes: FlashNote[]): Promise<void> {
    if (!this.filePath) {
      throw new Error('FlashNoteService not initialized');
    }
    const file = fs.openSync(this.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      const bytes = new util.TextEncoder().encodeInto(JSON.stringify(notes));
      fs.writeSync(file.fd, bytes.buffer);
    } finally {
      fs.closeSync(file);
    }
  }

  async ingest(arrivals: FlashNote[]): Promise<FlashNote[]> {
    return this.withExclusive(async (): Promise<FlashNote[]> => {
      const next = mergeFlashNotes(await this.load(), arrivals);
      await this.save(next);
      return next;
    });
  }

  async archive(flashId: string): Promise<void> {
    await this.withExclusive(async (): Promise<void> => {
      await this.save(archiveFlash(await this.load(), flashId));
    });
  }

  async markConverted(flashId: string, taskId: string): Promise<void> {
    await this.withExclusive(async (): Promise<void> => {
      await this.save(markFlashConverted(await this.load(), flashId, taskId));
    });
  }
}
