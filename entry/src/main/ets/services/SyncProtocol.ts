export interface SyncEvent {
  eventId: string;
  taskId: string;
  actionId: string;
  baseRevision: number;
  type: 'start' | 'resume' | 'pause' | 'complete' | 'change';
  origin: 'watch';
  createdAt: number;
}

export interface SyncAck {
  eventId: string;
  status: string;
  currentRevision?: number;
}

export function pendingActionEvents(events: object[], acks: SyncAck[]): SyncEvent[] {
  const acknowledged = new Set(acks.map((ack: SyncAck) => ack.eventId));
  const seen = new Set<string>();
  const pending: SyncEvent[] = [];
  for (const raw of events) {
    const event = raw as SyncEvent;
    if (!event || typeof event.eventId !== 'string' || !event.eventId ||
      typeof event.taskId !== 'string' || !event.taskId ||
      typeof event.actionId !== 'string' || !event.actionId ||
      typeof event.baseRevision !== 'number' || event.baseRevision < 1 ||
      typeof event.createdAt !== 'number' || event.origin !== 'watch' ||
      ['start', 'resume', 'pause', 'complete', 'change'].indexOf(event.type) < 0 ||
      acknowledged.has(event.eventId) || seen.has(event.eventId)) {
      continue;
    }
    seen.add(event.eventId);
    pending.push(event);
  }
  return pending;
}

/** Keep acknowledgements for every event still present in the watch-owned queue. */
export function retainedActionAcks(events: object[], acks: SyncAck[]): SyncAck[] {
  const currentIds = new Set<string>();
  for (const raw of events) {
    const event = raw as SyncEvent;
    if (event && typeof event.eventId === 'string') {
      currentIds.add(event.eventId);
    }
  }
  const seen = new Set<string>();
  return acks.filter((ack: SyncAck) => {
    if (!currentIds.has(ack.eventId) || seen.has(ack.eventId)) {
      return false;
    }
    seen.add(ack.eventId);
    return true;
  });
}

export interface SyncFlashNote {
  flashId: string;
  content: string;
  sourceDevice: 'watch';
  createdAt: number;
  syncStatus: 'pending';
}

export function pendingFlashNotes(rawNotes: object[], ackedIds: string[]): SyncFlashNote[] {
  const acknowledged = new Set(ackedIds);
  const seen = new Set<string>();
  const pending: SyncFlashNote[] = [];
  for (const raw of rawNotes) {
    const note = raw as SyncFlashNote;
    if (!note || typeof note.flashId !== 'string' || !note.flashId ||
      typeof note.content !== 'string' || !note.content.trim() ||
      typeof note.createdAt !== 'number' || note.sourceDevice !== 'watch' ||
      acknowledged.has(note.flashId) || seen.has(note.flashId)) {
      continue;
    }
    seen.add(note.flashId);
    pending.push(note);
  }
  return pending;
}

export function retainedFlashAcks(rawNotes: object[], ackedIds: string[]): string[] {
  const currentIds = new Set<string>();
  for (const raw of rawNotes) {
    const note = raw as SyncFlashNote;
    if (note && typeof note.flashId === 'string') {
      currentIds.add(note.flashId);
    }
  }
  const seen = new Set<string>();
  return ackedIds.filter((id: string) => {
    if (!currentIds.has(id) || seen.has(id)) {
      return false;
    }
    seen.add(id);
    return true;
  });
}
