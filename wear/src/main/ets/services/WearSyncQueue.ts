export interface WearActionEvent {
  eventId: string;
  taskId: string;
  actionId: string;
  baseRevision: number;
  type: 'start' | 'resume' | 'pause' | 'complete' | 'change';
  origin: 'watch';
  createdAt: number;
}

/** Pure queue state; the caller persists pending() before attempting KV writes. */
export class WearSyncQueue {
  private events: WearActionEvent[];

  constructor(initial: WearActionEvent[] = []) {
    this.events = initial.filter((event: WearActionEvent) => !!event.eventId);
  }

  enqueue(event: WearActionEvent): void {
    if (!this.events.some((item: WearActionEvent) => item.eventId === event.eventId)) {
      this.events.push(event);
    }
  }

  enqueueOperation(taskId: string, actionId: string, revision: number,
    type: WearActionEvent['type'], sequence: number, now: number):
    { event: WearActionEvent; nextSequence: number } {
    const existing = this.events.find((event: WearActionEvent) => event.taskId === taskId &&
      event.actionId === actionId && event.baseRevision === revision && event.type === type);
    if (existing) {
      return { event: existing, nextSequence: sequence };
    }
    const event: WearActionEvent = {
      eventId: `watch_${encodeURIComponent(actionId)}_${sequence}`,
      taskId: taskId,
      actionId: actionId,
      baseRevision: revision,
      type: type,
      origin: 'watch',
      createdAt: now
    };
    this.enqueue(event);
    return { event, nextSequence: sequence + 1 };
  }

  pending(): WearActionEvent[] {
    return [...this.events];
  }

  ack(eventId: string): void {
    this.events = this.events.filter((event: WearActionEvent) => event.eventId !== eventId);
  }
}

/** Only phone-marked bundles may replace the watch's cached Action projection. */
export function shouldAdoptPhoneProjection(bundle: { source?: string; updatedAt: number },
  _localStamp: number): boolean {
  return bundle.source === 'phone';
}
