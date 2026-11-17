import type { TaskPlan, WorkflowTask, FirstStepCard } from './WorkflowV21Contracts.ts';

/** Map only the confirmed current Step; never regenerate an existing identical Action. */
export function materializeConfirmedPlan(plan: TaskPlan, now: number, existing?: WorkflowTask): WorkflowTask {
  const step = plan.steps.find(s => s.stepId === plan.firstStepId)!;
  const id = existing?.id ?? plan.taskId ?? `task_${encodeURIComponent(plan.planId)}`;
  const keepAction = existing && existing.focusStep.status !== 'completed' && existing.focusStep.text === step.text;
  return { ...(existing ?? {}), id, title: plan.title, content: plan.userGoal,
    completed: false, createdAt: existing?.createdAt ?? now, planId: plan.planId, planRevision: plan.planRevision,
    focusStep: keepAction ? { ...existing.focusStep } : {
      taskId: id, actionId: `action_${encodeURIComponent(id)}_${encodeURIComponent(plan.planId)}_${plan.planRevision}_${encodeURIComponent(step.stepId)}`,
      text: step.text, status: 'ready', order: step.order, updatedAt: now, revision: 1, generationSource: 'rule'
    } };
}
export function firstStepCard(task: WorkflowTask, stepId: string, expiresAt: string): FirstStepCard {
  return { schemaVersion: '2.1.0', cardId: `card_${task.focusStep.actionId}_${task.focusStep.revision}`,
    taskId: task.id, actionId: task.focusStep.actionId, actionRevision: task.focusStep.revision,
    stepId, title: task.title, action: task.focusStep.text, expiresAt, choices: ['start','complete','change','pause'] };
}
