export interface CardActionEvent {
  eventId: string;
  taskId: string;
  actionId: string;
  baseRevision: number;
  type: 'start' | 'complete';
  origin: 'card';
  createdAt: number;
}

export function cardEventForTap(taskId: string, actionId: string,
  revision: number, action: string, now: number): CardActionEvent | undefined {
  if (!taskId || !actionId || !Number.isInteger(revision) || revision < 1 ||
    (action !== 'start' && action !== 'complete')) {
    return undefined;
  }
  return {
    eventId: `card_${encodeURIComponent(taskId)}_${encodeURIComponent(actionId)}_${revision}_${action}`,
    taskId: taskId,
    actionId: actionId,
    baseRevision: revision,
    type: action,
    origin: 'card',
    createdAt: now
  };
}
