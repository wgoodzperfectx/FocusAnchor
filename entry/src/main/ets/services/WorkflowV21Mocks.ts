import type { WorkflowData, WorkflowEvent, WorkflowTask, TaskPlan, ContextFeatures, InterventionDecision, ProviderInfo, FirstStepCard, WorkflowDeps, TaskStore, ConfirmationEvent, ConfirmedCandidate } from './WorkflowV21Contracts.ts';
import { emptyWorkflowData } from './WorkflowV21Contracts.ts';

const copy = <T>(value: T): T => value === undefined ? value : JSON.parse(JSON.stringify(value));
const info = (id: string): ProviderInfo => ({ id, kind: 'mock', version: '2.1.0-mock.1', capability: 'available', prerequisites: [] });
export type MockMode = 'normal'|'invalid'|'error'|'timeout'|'offline';
async function respond<T>(mode: MockMode, value: T): Promise<T> {
  if (mode === 'error') throw new Error('INJECTED_ERROR');
  if (mode === 'timeout') return new Promise<T>(() => {});
  if (mode === 'invalid') return { invalid: true } as T;
  return copy(value);
}
export class MockTaskStore implements TaskStore {
  info = info('mock-task-store'); private data: WorkflowData; private tail: Promise<unknown> = Promise.resolve();
  failNextWrite = false; failNextRead = false;
  constructor(initial = emptyWorkflowData()) { this.data = copy(initial); }
  async read(): Promise<WorkflowData> { if (this.failNextRead) { this.failNextRead = false; throw new Error('STORE_READ_FAILED'); } return copy(this.data); }
  transact<T>(work: (state: WorkflowData) => T): Promise<T> {
    const result = this.tail.then(() => {
      const next = copy(this.data); const value = work(next);
      if (this.failNextWrite) { this.failNextWrite = false; throw new Error('STORE_WRITE_FAILED'); }
      this.data = next; return copy(value);
    });
    this.tail = result.catch(() => {}); return result;
  }
}
export class MockTaskPlanner {
  info = info('mock-task-planner'); calls = 0; mode: MockMode = 'normal';
  async plan(input: { event: WorkflowEvent; existing?: WorkflowTask; previous?: TaskPlan; edit?: string }): Promise<TaskPlan> {
    this.calls++;
    const { event, existing, previous, edit } = input;
    const id = previous?.planId ?? `plan_${event.eventId}`;
    const steps = previous ? previous.steps.map(s => ({ ...s, text: s.stepId === previous.firstStepId ? edit! : s.text })) : existing ?
      [{ stepId: `${id}_0`, order: 0, text: existing.focusStep.text, status: 'proposed' as const, estimatedStartMinutes: 2 as const }] :
      [`打开「${event.payload.title ?? event.payload.text}」相关材料`, '列出三个要点', '完成第一个要点'].map((text, i) => ({ stepId: `${id}_${i}`, order: i, text, status: 'proposed' as const, estimatedStartMinutes: 2 as const }));
    return respond(this.mode, { schemaVersion: '2.1.0', planId: id, planRevision: (previous?.planRevision ?? 0) + 1,
      taskId: existing?.id ?? event.payload.taskId, title: previous?.title ?? existing?.title ?? event.payload.title ?? event.payload.text!,
      userGoal: previous?.userGoal ?? existing?.content ?? event.payload.text ?? event.payload.title!, steps,
      firstStepId: previous?.firstStepId ?? steps[0].stepId, sourceEventId: event.eventId,
      plannerProvider: this.info.id, plannerVersion: this.info.version });
  }
}
export class MockContextEstimator {
  info = info('mock-context-estimator'); calls = 0; mode: MockMode = 'normal'; candidateTaskId?: string; candidateReferenceId?: string; lastResult?: ContextFeatures;
  private now: () => number;
  constructor(now: () => number) { this.now = now; }
  async estimate(event: WorkflowEvent): Promise<ContextFeatures> {
    this.calls++;
    const evidence = this.candidateTaskId ? [`task:${this.candidateTaskId}`] : this.candidateReferenceId ? [`memory:${this.candidateReferenceId}`] : [];
    this.lastResult = { schemaVersion: '2.1.0', contextId: `context_${event.eventId}`, timestamp: new Date(this.now()).toISOString(),
      taskContext: { candidateTaskId: this.candidateTaskId, candidateReferenceId: this.candidateReferenceId, candidateSource: this.candidateTaskId ? 'existing_task' : this.candidateReferenceId ? 'user_confirmed_memory' : undefined, candidateEvidenceIds: evidence },
      temporalContext: { localTime: new Date(this.now()).toISOString(), quietHours: false },
      dataQuality: 'partial', evidenceSources: evidence,
      missingFields: ['optionalLocationContext','optionalBehaviorFeatures','optionalPhysiologicalFeatures'] };
    return respond(this.mode, this.lastResult);
  }
}
export class MockInterventionPolicy {
  info = info('mock-intervention-policy'); calls = 0; mode: MockMode = 'normal'; decision: InterventionDecision['decision'] = 'ABSTAIN';
  async decide(context: ContextFeatures): Promise<InterventionDecision> {
    this.calls++;
    return respond(this.mode, { schemaVersion: '2.1.0', decisionId: `decision_${context.contextId}`, contextId: context.contextId,
      decision: this.decision, policyVersion: this.info.version, reasonCodes: [`MOCK_${this.decision}`], evidenceReferences: context.evidenceSources,
      suggestedActionType: this.decision === 'INTERVENE' ? 'resume_step' : this.decision === 'ASK' ? 'clarify' : 'none',
      optionalDeferUntil: this.decision === 'DEFER' ? new Date(Date.parse(context.timestamp) + 30000).toISOString() : undefined });
  }
}
export class MockDeviceSync {
  info = info('mock-device-sync'); calls = 0; mode: MockMode = 'normal'; sent: FirstStepCard[] = [];
  private now: () => number;
  constructor(now: () => number) { this.now = now; }
  async send(card: FirstStepCard): Promise<unknown> {
    this.calls++; this.sent.push(copy(card));
    return respond(this.mode, { receiptId: `delivery_${card.cardId}_${this.mode}`, actionId: card.actionId, target: 'watch',
      status: this.mode === 'offline' ? 'offline' : 'delivered', transportVersion: this.info.version, timestamp: new Date(this.now()).toISOString(),
      errorCode: this.mode === 'offline' ? 'DEVICE_OFFLINE' : undefined });
  }
}
export class MockUserConfirmation {
  info = info('mock-user-confirmation'); mode: MockMode = 'normal'; calls = 0;
  async respond(plan: TaskPlan, choice: ConfirmationEvent['choice'], timestamp: string, edit?: string): Promise<ConfirmationEvent> {
    this.calls++;
    return respond(this.mode, { eventId: `confirmation_${plan.planId}_${plan.planRevision}_${choice}`, planId: plan.planId,
      planRevision: plan.planRevision, actor: 'user', choice, timestamp, requestedEdit: edit });
  }
}
export function createMockRuntime(nowMs: number, store: TaskStore = new MockTaskStore()) {
  let now = nowMs;
  const clock = { advance(ms: number) { now += ms; }, now: () => now };
  const auth = { granted: true, version: 1, validSource: true, quietHours: false, frequencyAllowed: true, allowAsk: true, sandboxAllowed: true,
    scopes: ['focus_support','proactive_nudges','thought_sandbox'], grantIds: ['grant-1'] };
  const planner = new MockTaskPlanner(); const estimator = new MockContextEstimator(clock.now);
  const candidates: ConfirmedCandidate[] = [];
  const policy = new MockInterventionPolicy(); const device = new MockDeviceSync(clock.now); const confirmation = new MockUserConfirmation();
  const deps: WorkflowDeps = { now: clock.now, timeoutMs: 15, store, planner, estimator, policy, device, schedulerAvailable: true,
    resolveCandidate: async id => copy(candidates.find(c => c.referenceId === id)),
    authorize: async event => ({ ...auth, allowed: auth.granted && event.consent.grantIds.every(id => auth.grantIds.includes(id)) }) };
  return { deps, clock, auth, planner, estimator, policy, device, confirmation, store, candidates };
}
