export interface CurrentTaskLike {
  completed: boolean;
  focusStep?: { status: string };
}

/** Temporary UI selection until the canonical currentActionId interface is available. */
export function selectUnambiguousTask<T extends CurrentTaskLike>(tasks: T[]): T | undefined {
  const pending = tasks.filter((task: T) => !task.completed);
  const active = pending.filter((task: T) => task.focusStep?.status === 'in_progress' || task.focusStep?.status === 'paused');
  if (active.length > 0) return active.length === 1 ? active[0] : undefined;
  const ready = pending.filter((task: T) => task.focusStep?.status === 'ready');
  if (ready.length > 0) return ready.length === 1 ? ready[0] : undefined;
  return pending.length === 1 ? pending[0] : undefined;
}
