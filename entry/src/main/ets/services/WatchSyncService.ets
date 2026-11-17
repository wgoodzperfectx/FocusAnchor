import { common } from '@kit.AbilityKit';
import { distributedKVStore } from '@kit.ArkData';
import { ActionEvent, ActionEventResult, FlashNote, StudyTask } from '../models/AppTypes';
import { pendingActionEvents, pendingFlashNotes, retainedActionAcks,
  retainedFlashAcks, SyncAck } from './SyncProtocol';

const STORE_ID: string = 'focux_watch_sync';
const TASKS_KEY: string = 'tasks_sync';
const LANG_KEY: string = 'language_sync';
const ACTION_EVENTS_KEY: string = 'action_events_sync';
const ACTION_ACKS_KEY: string = 'action_acks_sync';
const FLASH_NOTES_KEY: string = 'flash_notes_sync';
const FLASH_ACKS_KEY: string = 'flash_acks_sync';

export interface TaskSyncBundle {
  updatedAt: number;
  tasks: StudyTask[];
  source?: 'phone';
}

/**
 * Phone-owned task projections and watch-origin Action events via distributed KV.
 */
export class WatchSyncService {
  private static instance: WatchSyncService | undefined;
  private kvStore: distributedKVStore.SingleKVStore | undefined;
  private ready: boolean = false;
  private processingEvents: boolean = false;
  private rerunEvents: boolean = false;
  private processingFlash: boolean = false;
  private rerunFlash: boolean = false;

  static getInstance(): WatchSyncService {
    if (!WatchSyncService.instance) {
      WatchSyncService.instance = new WatchSyncService();
    }
    return WatchSyncService.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.ready && this.kvStore) {
      return;
    }
    try {
      const kvManager = distributedKVStore.createKVManager({
        context: context,
        bundleName: 'com.focusanchor.focuxanchor'
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

  /** Phone adjudicates watch events and acknowledges only after the task file is saved. */
  async startActionListening(onEvent: (event: ActionEvent) => Promise<ActionEventResult>): Promise<void> {
    if (!this.ready || !this.kvStore) {
      return;
    }
    this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, () => {
      this.drainActionEvents(onEvent).catch(() => console.error('Watch action drain failed'));
    });
    await this.drainActionEvents(onEvent);
  }

  private async drainActionEvents(onEvent: (event: ActionEvent) => Promise<ActionEventResult>): Promise<void> {
    if (!this.kvStore) {
      return;
    }
    if (this.processingEvents) {
      this.rerunEvents = true;
      return;
    }
    this.processingEvents = true;
    try {
      let events: object[] = [];
      let acks: SyncAck[] = [];
      try {
        const raw = await this.kvStore.get(ACTION_EVENTS_KEY);
        const parsed = typeof raw === 'string' ? JSON.parse(raw) as object[] : [];
        events = Array.isArray(parsed) ? parsed : [];
      } catch (_e) {
        events = [];
      }
      try {
        const raw = await this.kvStore.get(ACTION_ACKS_KEY);
        const parsed = typeof raw === 'string' ? JSON.parse(raw) as SyncAck[] : [];
        acks = Array.isArray(parsed) ? parsed : [];
      } catch (_e) {
        acks = [];
      }
      const retained = retainedActionAcks(events, acks);
      let changed = retained.length !== acks.length;
      acks = retained;
      for (const event of pendingActionEvents(events, acks)) {
        try {
          const result = await onEvent(event as ActionEvent);
          acks.push({ eventId: event.eventId, status: result.status,
            currentRevision: result.currentRevision });
          changed = true;
        } catch (_e) {
          // No ack: the watch retains and retries the event after reconnection.
          console.error('Watch action not acknowledged');
        }
      }
      if (changed) {
        await this.kvStore.put(ACTION_ACKS_KEY, JSON.stringify(acks));
      }
    } finally {
      this.processingEvents = false;
      if (this.rerunEvents) {
        this.rerunEvents = false;
        await this.drainActionEvents(onEvent);
      }
    }
  }

  /** Persist the watch inbox on the phone before confirming flash IDs. */
  async startFlashListening(onNotes: (notes: FlashNote[]) => Promise<void>): Promise<void> {
    if (!this.ready || !this.kvStore) {
      return;
    }
    this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL, () => {
      this.drainFlashNotes(onNotes).catch(() => console.error('Watch flash drain failed'));
    });
    await this.drainFlashNotes(onNotes);
  }

  private async drainFlashNotes(onNotes: (notes: FlashNote[]) => Promise<void>): Promise<void> {
    if (!this.kvStore) {
      return;
    }
    if (this.processingFlash) {
      this.rerunFlash = true;
      return;
    }
    this.processingFlash = true;
    try {
      let rawNotes: object[] = [];
      let acks: string[] = [];
      try {
        const raw = await this.kvStore.get(FLASH_NOTES_KEY);
        const parsed = typeof raw === 'string' ? JSON.parse(raw) as object[] : [];
        rawNotes = Array.isArray(parsed) ? parsed : [];
      } catch (_e) {
        rawNotes = [];
      }
      try {
        const raw = await this.kvStore.get(FLASH_ACKS_KEY);
        const parsed = typeof raw === 'string' ? JSON.parse(raw) as string[] : [];
        acks = Array.isArray(parsed) ? parsed : [];
      } catch (_e) {
        acks = [];
      }
      const retained = retainedFlashAcks(rawNotes, acks);
      let changed = retained.length !== acks.length;
      acks = retained;
      const pending = pendingFlashNotes(rawNotes, acks);
      if (pending.length > 0) {
        const arrivals: FlashNote[] = pending.map((note): FlashNote => ({
          flashId: note.flashId,
          content: note.content,
          sourceDevice: 'watch',
          createdAt: note.createdAt,
          syncStatus: 'pending'
        }));
        await onNotes(arrivals);
        for (const note of pending) {
          acks.push(note.flashId);
        }
        changed = true;
      }
      if (changed) {
        await this.kvStore.put(FLASH_ACKS_KEY, JSON.stringify(acks));
      }
    } finally {
      this.processingFlash = false;
      if (this.rerunFlash) {
        this.rerunFlash = false;
        await this.drainFlashNotes(onNotes);
      }
    }
  }

  /** Publish the phone's current task projection to the watch. */
  async pushTasksToWatch(tasks: StudyTask[]): Promise<void> {
    if (!this.ready || !this.kvStore) {
      return;
    }
    try {
      const updatedAt = Date.now();
      const bundle: TaskSyncBundle = { updatedAt, tasks, source: 'phone' };
      await this.kvStore.put(TASKS_KEY, JSON.stringify(bundle));
    } catch (error) {
      console.error('WatchSync push failed');
    }
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
