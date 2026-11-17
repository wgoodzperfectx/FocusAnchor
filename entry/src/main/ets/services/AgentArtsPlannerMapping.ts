import type { TaskPlan } from './WorkflowV21Contracts.ts';
import { validateTaskPlan } from './WorkflowV21Validation.ts';

/** Local identity is supplied by the authoritative App. A model cannot mint these values. */
export interface PlannerLocalIdentity {
  planId: string;
  planRevision: number;
  taskId?: string;
  stepIds: string[];
  estimatedStartMinutes: (1|2)[];
  sourceEventId: string;
  correlationId: string;
  providerId: string;
  providerVersion: string;
}

const draftKeys = ['correlationId', 'errorCode', 'question', 'resultType',
  'sourceEventId', 'steps', 'title', 'userGoal'];
const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);
const nonempty = (value: unknown, max: number): value is string =>
  typeof value === 'string' && value.trim().length > 0 && value.length <= max;

/** Maps a validated STEP draft to the existing TaskPlan schema; CLARIFY/ERROR stay separate. */
export function mapAgentArtsStepDraftToTaskPlan(draft: unknown, local: PlannerLocalIdentity): TaskPlan {
  if (!local || !record(draft) || Object.keys(draft).sort().join('|') !== draftKeys.join('|') ||
      draft.resultType !== 'STEP' || draft.sourceEventId !== local.sourceEventId ||
      draft.correlationId !== local.correlationId || !nonempty(draft.title, 120) ||
      !nonempty(draft.userGoal, 500) || !Array.isArray(draft.steps) ||
      draft.steps.length < 1 || draft.steps.length > 5 ||
      !draft.steps.every((step: unknown) => nonempty(step, 500)) ||
      draft.question !== '' || draft.errorCode !== '' ||
      !Array.isArray(local.stepIds) || local.stepIds.length !== draft.steps.length ||
      !Array.isArray(local.estimatedStartMinutes) ||
      local.estimatedStartMinutes.length !== draft.steps.length ||
      !nonempty(local.providerId, 128) || !nonempty(local.providerVersion, 128)) {
    throw new Error('AGENTARTS_DRAFT_INVALID_SCHEMA');
  }
  const steps = (draft.steps as string[]).map((text, order) => ({
    stepId: local.stepIds[order], order, text, status: 'proposed' as const,
    estimatedStartMinutes: local.estimatedStartMinutes[order]
  }));
  const plan: TaskPlan = {
    schemaVersion: '2.1.0', planId: local.planId, planRevision: local.planRevision,
    taskId: local.taskId, title: draft.title, userGoal: draft.userGoal,
    steps, firstStepId: local.stepIds[0], sourceEventId: local.sourceEventId,
    plannerProvider: local.providerId, plannerVersion: local.providerVersion
  };
  if (!validateTaskPlan(plan)) throw new Error('AGENTARTS_DRAFT_INVALID_PLAN');
  return plan;
}
