/** Plain TypeScript shape so this pure reducer can run in Node tests and ArkTS. */
interface StepLike {
  text: string;
  status: 'ready' | 'in_progress' | 'paused' | 'completed';
  updatedAt: number;
  taskId?: string;
  actionId?: string;
  order?: number;
  revision?: number;
  generationSource?: 'agent' | 'rule' | 'manual' | 'legacy';
  appliedEventIds?: string[];
}

interface TaskLike {
  id: string;
  completed: boolean;
  createdAt: number;
  focusStep?: StepLike;
}

export interface NormalizedAction {
  taskId: string;
  actionId: string;
  text: string;
  status: 'ready' | 'in_progress' | 'completed';
  order: number;
  updatedAt: number;
  revision: number;
  generationSource: 'agent' | 'rule' | 'manual' | 'legacy';
  appliedEventIds?: string[];
}

export interface ActionEventInput {
  eventId: string;
  taskId: string;
  actionId: string;
  baseRevision: number;
  type: 'start' | 'resume' | 'pause' | 'complete' | 'change';
  origin: 'phone' | 'card' | 'watch';
  createdAt: number;
}

export interface ActionReduction<T> {
  status: 'applied' | 'duplicate' | 'conflict' | 'missing' | 'needs_step' | 'session_only';
  tasks: T[];
  currentRevision?: number;
}

/** Give an existing first step a stable identity without inventing a step. */
export function normalizeFocusAction(task: TaskLike): NormalizedAction | undefined {
  const step: StepLike | undefined = task.focusStep;
  if (task.completed || !step || !step.text.trim()) {
    return undefined;
  }
  const updatedAt = Number.isFinite(step.updatedAt) ? step.updatedAt : task.createdAt;
  return {
    taskId: task.id,
    actionId: step.actionId && step.actionId.length > 0 ? step.actionId :
      `legacy_${encodeURIComponent(task.id)}_${updatedAt}`,
    text: step.text,
    status: step.status === 'paused' ? 'in_progress' : step.status,
    order: typeof step.order === 'number' ? step.order : 0,
    updatedAt,
    revision: typeof step.revision === 'number' && step.revision > 0 ? step.revision : 1,
    generationSource: step.generationSource ?? 'legacy',
    appliedEventIds: step.appliedEventIds
  };
}

/** Persist the canonical action shape while retaining every task field. */
export function materializeTaskAction<T extends TaskLike>(task: T): T {
  const action = normalizeFocusAction(task);
  if (!action) {
    return task;
  }
  const step = task.focusStep;
  if (step?.actionId === action.actionId && step?.taskId === action.taskId &&
    step?.revision === action.revision && step?.order === action.order &&
    step?.generationSource === action.generationSource && step?.status === action.status &&
    step?.appliedEventIds === action.appliedEventIds) {
    return task;
  }
  return { ...task, focusStep: action };
}

/** Pure host-side state transition. The caller must persist before publishing projections. */
export function applyActionEventToTasks<T extends TaskLike>(tasks: T[], event: ActionEventInput): ActionReduction<T> {
  const index = tasks.findIndex((task: T) => task.id === event.taskId);
  if (index < 0 || tasks[index].completed) {
    return { status: 'missing', tasks };
  }
  const task = tasks[index];
  const action = normalizeFocusAction(task);
  if (!action) {
    return { status: 'missing', tasks };
  }
  if (action.appliedEventIds?.includes(event.eventId)) {
    return { status: 'duplicate', tasks, currentRevision: action.revision };
  }
  if (action.actionId !== event.actionId || action.revision !== event.baseRevision) {
    return { status: 'conflict', tasks, currentRevision: action.revision };
  }
  if (event.type === 'change') {
    return { status: 'needs_step', tasks, currentRevision: action.revision };
  }
  if (event.type === 'pause') {
    return { status: action.status === 'in_progress' ? 'session_only' : 'conflict',
      tasks, currentRevision: action.revision };
  }
  if (event.type === 'resume') {
    return { status: action.status === 'in_progress' ? 'session_only' : 'conflict',
      tasks, currentRevision: action.revision };
  }
  const nextStatus = event.type === 'complete' ? 'completed' : 'in_progress';
  if (action.status === 'completed' || (nextStatus === 'in_progress' && action.status !== 'ready')) {
    return { status: 'conflict', tasks, currentRevision: action.revision };
  }
  const nextAction: NormalizedAction = {
    ...action,
    status: nextStatus,
    updatedAt: Math.max(event.createdAt, action.updatedAt + 1),
    revision: action.revision + 1,
    appliedEventIds: [...(action.appliedEventIds ?? []).slice(-19), event.eventId]
  };
  const nextTasks = tasks.map((item: T, itemIndex: number): T =>
    itemIndex === index ? { ...item, focusStep: nextAction } : item);
  return { status: 'applied', tasks: nextTasks, currentRevision: nextAction.revision };
}
