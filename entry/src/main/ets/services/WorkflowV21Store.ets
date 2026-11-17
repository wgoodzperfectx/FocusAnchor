import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { WorkflowV21SnapshotStore, SnapshotIO } from './WorkflowV21SnapshotStore';

/** Keep the last complete snapshot until the replacement has been flushed and renamed. */
class WorkflowV21FileIO implements SnapshotIO {
  private path: string;
  private static sequence: number = 0;

  constructor(context: common.Context) {
    this.path = `${context.filesDir}/workflow_v21.json`;
  }

  async read(): Promise<string | undefined> {
    if (!fs.accessSync(this.path)) {
      return undefined;
    }
    const file = fs.openSync(this.path, fs.OpenMode.READ_ONLY);
    try {
      const size = fs.statSync(this.path).size;
      const buffer = new ArrayBuffer(size);
      if (fs.readSync(file.fd, buffer) !== size) {
        throw new Error('INCOMPLETE_WORKFLOW_SNAPSHOT');
      }
      return new util.TextDecoder().decodeToString(new Uint8Array(buffer));
    } finally {
      fs.closeSync(file);
    }
  }

  async replace(text: string): Promise<void> {
    const temporary = `${this.path}.${Date.now()}_${++WorkflowV21FileIO.sequence}.tmp`;
    try {
      const file = fs.openSync(temporary, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        const bytes = new util.TextEncoder().encodeInto(text);
        if (fs.writeSync(file.fd, bytes.buffer) !== bytes.byteLength) {
          throw new Error('INCOMPLETE_WORKFLOW_WRITE');
        }
        fs.fsyncSync(file.fd);
      } finally {
        fs.closeSync(file);
      }
      fs.renameSync(temporary, this.path);
    } catch (_) {
      try {
        if (fs.accessSync(temporary)) {
          fs.unlinkSync(temporary);
        }
      } catch (_) {
        // A leftover temporary file is never read as a committed snapshot.
      }
      throw new Error('WORKFLOW_SNAPSHOT_REPLACE_FAILED');
    }
  }
}

export class WorkflowV21Store extends WorkflowV21SnapshotStore {
  constructor(context: common.Context) {
    super(new WorkflowV21FileIO(context));
  }
}
