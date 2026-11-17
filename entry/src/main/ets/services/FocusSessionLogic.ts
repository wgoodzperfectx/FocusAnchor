export interface FocusSessionRecord {
  sessionId: string;
  taskId: string;
  actionId: string;
  status: 'IDLE' | 'RUNNING' | 'PAUSED';
  updatedAt: number;
  appliedEventIds?: string[];
}

function recordEvent(session: FocusSessionRecord, eventId?: string): FocusSessionRecord {
  return eventId ? { ...session, appliedEventIds: [...(session.appliedEventIds ?? []).slice(-99), eventId] } : session;
}

export function transitionFocusSession(
  current: FocusSessionRecord | undefined,
  taskId: string,
  actionId: string,
  operation: 'start' | 'pause' | 'resume',
  now: number,
  eventId?: string
): FocusSessionRecord | undefined {
  if (eventId && current?.appliedEventIds?.includes(eventId)) {
    return current;
  }
  if (operation === 'start') {
    if (current && current.taskId === taskId && current.actionId === actionId) {
      return recordEvent(current.status === 'RUNNING' ? current :
        { ...current, status: 'RUNNING', updatedAt: now }, eventId);
    }
    return recordEvent({ sessionId: `session_${encodeURIComponent(actionId)}_${now}`, taskId, actionId,
      status: 'RUNNING', updatedAt: now }, eventId);
  }
  if (!current || current.taskId !== taskId || current.actionId !== actionId) {
    return undefined;
  }
  if (operation === 'pause' && current.status === 'RUNNING') {
    return recordEvent({ ...current, status: 'PAUSED', updatedAt: now }, eventId);
  }
  if (operation === 'resume' && current.status === 'PAUSED') {
    return recordEvent({ ...current, status: 'RUNNING', updatedAt: now }, eventId);
  }
  return recordEvent(current, eventId);
}
