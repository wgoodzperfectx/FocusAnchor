import type { TaskStore, WorkflowData, ProviderInfo } from './WorkflowV21Contracts.ts';
import { emptyWorkflowData } from './WorkflowV21Contracts.ts';

export interface SnapshotIO {
  read(): Promise<string | undefined>;
  /** Replace the snapshot atomically (same-volume temporary file + rename). */
  replace(text: string): Promise<void>;
}
const clone = <T>(v: T): T => v === undefined ? v : JSON.parse(JSON.stringify(v));
export class WorkflowV21SnapshotStore implements TaskStore {
  info: ProviderInfo = { id: 'local-snapshot-store', kind: 'real', version: '2.1.0', capability: 'available', prerequisites: [] };
  private io: SnapshotIO; private data?: WorkflowData; private tail: Promise<unknown> = Promise.resolve();
  constructor(io: SnapshotIO) { this.io = io; }
  private async load(): Promise<WorkflowData> {
    if (this.data) return this.data;
    const raw = await this.io.read();
    if (raw === undefined) { this.data = emptyWorkflowData(); return this.data; }
    const parsed = JSON.parse(raw) as WorkflowData;
    const arrays = ['tasks','drafts','suggestions','schedules','outbox','receipts','feedback','audit','processed','confirmations','sandbox'];
    if (parsed.schemaVersion !== '2.1.0' || !arrays.every(k => Array.isArray((parsed as any)[k])) || typeof parsed.controls?.paused !== 'boolean' || typeof parsed.controls?.suppressed !== 'boolean') throw new Error('CORRUPT_WORKFLOW_SNAPSHOT');
    this.data = parsed; return parsed;
  }
  async read(): Promise<WorkflowData> { await this.tail; return clone(await this.load()); }
  transact<T>(work: (data: WorkflowData) => T): Promise<T> {
    const next = this.tail.then(async () => {
      const data = clone(await this.load()); const result = work(data);
      await this.io.replace(JSON.stringify(data)); this.data = data; return clone(result);
    });
    this.tail = next.catch(() => {}); return next;
  }
}
