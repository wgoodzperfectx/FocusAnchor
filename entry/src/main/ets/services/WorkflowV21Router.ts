import type { WorkflowDeps, WorkflowData, WorkflowEvent, WorkflowResult, TaskPlan, ContextFeatures, InterventionDecision, ConfirmationEvent, ProviderInfo, WorkflowTask, Draft, OutboxItem } from './WorkflowV21Contracts.ts';
import { validateEvent, validateContextFeatures, validateInterventionDecision, validateTaskPlan, validateConfirmation, validateDeliveryReceipt, validateActionEvent } from './WorkflowV21Validation.ts';
import { materializeConfirmedPlan, firstStepCard } from './WorkflowV21Mapping.ts';
import { applyActionEventToTasks } from './ActionLogic.ts';

function fingerprint(value: unknown): string {
  // Equality only; this checksum is never used as authentication or as an ID.
  const stable = (v: any): string => v && typeof v === 'object' ? (Array.isArray(v) ? `[${v.map(stable).join(',')}]` : `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${stable(v[k])}`).join(',')}}`) : JSON.stringify(v);
  const input = stable(value); let hash = 2166136261;
  for (let i = 0; i < input.length; i++) hash = Math.imul(hash ^ input.charCodeAt(i), 16777619);
  return `${input.length}:${hash >>> 0}`;
}
const unsafe = (e: WorkflowEvent): boolean => /伤害自己|自杀|伤害别人|吃药|停药|调药|处方|诊断/.test(`${e.payload.title ?? ''} ${e.payload.text ?? ''}`);

/** No model policy lives here: every decision is delegated, validated, gated and audited. */
export class WorkflowV21 {
  private tail: Promise<unknown> = Promise.resolve();
  private deps: WorkflowDeps;
  constructor(deps: WorkflowDeps) { this.deps = deps; }
  private serial<T>(work: () => Promise<T>): Promise<T> {
    const next = this.tail.then(work, work); this.tail = next.catch(() => {}); return next;
  }
  private stamp(): string { return new Date(this.deps.now()).toISOString(); }
  private recordEvent(data: WorkflowData, e: WorkflowEvent, result: WorkflowResult): void {
    const key = `${e.source}:${e.eventId}`;
    if (!data.processed.some(x => x.key === key)) data.processed.push({ key, fingerprint: fingerprint(e), result });
  }
  private recordConfirmation(data: WorkflowData, c: ConfirmationEvent, result: WorkflowResult): void {
    const prior = data.confirmations.find(x => x.key === c.eventId);
    if (prior) prior.result = result;
    else data.confirmations.push({ key: c.eventId, fingerprint: fingerprint(c), timestamp: c.timestamp, result });
  }
  private pauseAll(data: WorkflowData): void {
    data.controls = { paused: true, suppressed: true };
    data.drafts.forEach(d => { if (d.state === 'pending') d.state = 'paused'; });
    data.schedules.forEach(s => s.state = 'cancelled');
    data.suggestions.forEach(s => { if (s.state === 'pending') s.state = 'paused'; });
  }
  private async call<T>(info: ProviderInfo, work: () => Promise<T>): Promise<T> {
    if (info.capability !== 'available' || (info.kind === 'real' && info.prerequisites.length)) throw new Error('PROVIDER_UNAVAILABLE');
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([work(), new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('PROVIDER_TIMEOUT')), this.deps.timeoutMs); })]);
    } finally { if (timer !== undefined) clearTimeout(timer); }
  }
  private async log(e: WorkflowEvent, result: WorkflowResult, provider?: ProviderInfo): Promise<WorkflowResult> {
    await this.deps.store.transact(data => { data.audit.push({ eventId: e.eventId, correlationId: e.correlationId, status: result.status, reason: result.reason, timestamp: this.stamp(), providerId: provider?.id, providerVersion: provider?.version, consentVersion: e.consent.version }); });
    return result;
  }
  private async gate(e: WorkflowEvent, context = e.channel === 'CONTEXT'): Promise<string | undefined> {
    if (Date.parse(e.expiresAt) <= this.deps.now() || Date.parse(e.occurredAt) > this.deps.now()) return 'EVENT_EXPIRED_OR_FUTURE';
    const auth = await this.deps.authorize(e);
    if (!auth.validSource) return 'UNTRUSTED_SOURCE';
    const scopes = ['focus_support', ...(context ? ['proactive_nudges'] : []), ...(e.type === 'location_scene' ? ['location'] : []), ...(e.type === 'physiology_abstract' ? ['physiology'] : []), ...(e.type === 'behavior_pattern' ? ['behavior_memory'] : [])];
    if (!auth.allowed || e.consent.version !== auth.version || !e.consent.grantIds.length || !scopes.every(s => auth.scopes.includes(s) && e.consent.scopeIds.includes(s))) return 'CONSENT_REQUIRED_OR_REVOKED';
    if (unsafe(e)) return 'SAFETY_HANDOFF';
    const data = await this.deps.store.read();
    if (context) {
      if (data.controls.paused || data.controls.suppressed) return 'USER_SUPPRESSED';
      if (auth.quietHours) return 'QUIET_HOURS';
      if (!auth.frequencyAllowed) return 'FREQUENCY_LIMIT';
    }
    return undefined;
  }
  dispatch(event: WorkflowEvent): Promise<WorkflowResult> { return this.serial(() => this.dispatchInternal(event)); }
  private async dispatchInternal(e: WorkflowEvent): Promise<WorkflowResult> {
    if (!validateEvent(e)) return { status: 'FAILED_SAFE', reason: 'INVALID_EVENT' };
    try {
      await this.log(e, { status: 'RECEIVED' });
      if (e.channel === 'USER' && e.type === 'focus_companion' && e.payload.companionAction === 'pause') {
        await this.deps.store.transact(data => { this.pauseAll(data); this.recordEvent(data, e, { status: 'PAUSED' }); });
        return this.log(e, { status: 'PAUSED' });
      }
      const gateBeforeReplay = await this.gate(e);
      if (gateBeforeReplay) return this.log(e, { status: 'BLOCKED', reason: gateBeforeReplay });
      const key = `${e.source}:${e.eventId}`; const hash = fingerprint(e);
      const previous = (await this.deps.store.read()).processed.find(x => x.key === key);
      if (previous) return previous.fingerprint === hash ? previous.result : { status: 'CONFLICT', reason: 'EVENT_ID_REUSED' };
      let result: WorkflowResult;
      const reason = await this.gate(e);
      if (reason) result = { status: 'BLOCKED', reason };
      else if (e.channel === 'CONTEXT') result = await this.context(e);
      else if (e.type === 'capture_thought') {
        const auth = await this.deps.authorize(e);
        if (!e.payload.text?.trim()) result = { status: 'AWAITING_CLARIFICATION', reason: 'THOUGHT_REQUIRED' };
        else {
          const save = e.payload.storageConfirmed === true && auth.sandboxAllowed;
          result = { status: save ? 'SANDBOXED' : 'NOT_STORED', message: save ? '已保存在本地闪念沙盒。' : '本次不保存闪念。' };
          await this.deps.store.transact(data => { if (save) data.sandbox.push({ eventId: e.eventId, text: e.payload.text!, timestamp: this.stamp() }); this.recordEvent(data, e, result); });
        }
      } else if (e.type === 'focus_companion') {
        const pause = e.payload.companionAction === 'pause';
        await this.deps.store.transact(data => {
          data.controls = { paused: pause, suppressed: pause };
          if (pause) { data.suggestions.forEach(s => { if (s.state === 'pending') s.state = 'paused'; }); data.schedules.forEach(s => s.state = 'cancelled'); }
        });
        result = { status: pause ? 'PAUSED' : 'COMPANION_CONFIGURED' };
      } else if (e.type === 'create_task' || e.type === 'resume_task') {
        // A fresh explicit request resumes the USER channel; proactive suppression remains.
        await this.deps.store.transact(data => { data.controls.paused = false; });
        result = await this.plan(e);
      }
      else result = { status: 'FAILED_SAFE', reason: 'USE_TYPED_ACTION_ENDPOINT' };
      if (!(await this.deps.store.read()).processed.some(x => x.key === key)) await this.deps.store.transact(data => { this.recordEvent(data, e, result); });
      // Never persist thought text in general event history.
      return await this.log(e, result);
    } catch (error) { return this.fail(e, error); }
  }
  private async fail(e: WorkflowEvent, error: unknown): Promise<WorkflowResult> {
    const reason = error instanceof Error && ['PROVIDER_TIMEOUT','PROVIDER_UNAVAILABLE','INVALID_CONTEXT','INVALID_DECISION','INVALID_PLAN','INVALID_RECEIPT','STORE_WRITE_FAILED'].includes(error.message) ? error.message : 'DEPENDENCY_FAILED';
    const result = { status: 'FAILED_SAFE', reason };
    try { return await this.log(e, result); } catch { return { status: 'FAILED_SAFE', reason: 'STORE_UNAVAILABLE' }; }
  }
  private async plan(e: WorkflowEvent, existing?: WorkflowTask, previous?: TaskPlan, edit?: string, decisionId?: string, confirmation?: ConfirmationEvent, suggestionId?: string): Promise<WorkflowResult> {
    if (!existing && e.payload.taskId) existing = (await this.deps.store.read()).tasks.find(t => t.id === e.payload.taskId && !t.completed);
    if (e.type === 'resume_task' && !existing) return { status: 'AWAITING_CLARIFICATION', reason: 'NO_RELIABLE_TASK' };
    if (!existing && !e.payload.title?.trim() && !e.payload.text?.trim()) return { status: 'AWAITING_CLARIFICATION', reason: 'TASK_REQUIRED' };
    await this.log(e, { status: 'PLANNING' }, this.deps.planner.info);
    const raw = await this.call(this.deps.planner.info, () => this.deps.planner.plan({ event: e, existing, previous, edit }));
    if (!validateTaskPlan(raw)) throw new Error('INVALID_PLAN');
    const plan = raw as TaskPlan;
    if (plan.steps.some(s => unsafe({ ...e, payload: { text: s.text, title: plan.title } }))) throw new Error('INVALID_PLAN');
    const expectedTaskId = existing?.id ?? e.payload.taskId;
    if (plan.taskId !== expectedTaskId || (!previous && plan.planRevision !== 1)) throw new Error('INVALID_PLAN');
    if (plan.sourceEventId !== e.eventId || (e.payload.taskId && plan.taskId !== e.payload.taskId) || (existing && plan.taskId !== existing.id) || (previous && (plan.planId !== previous.planId || plan.planRevision !== previous.planRevision + 1))) throw new Error('INVALID_PLAN');
    const gate = await this.gate(e); if (gate) return { status: 'BLOCKED', reason: gate };
    const result: WorkflowResult = { status: 'AWAITING_CONFIRMATION', plan };
    await this.deps.store.transact(data => {
      if (data.drafts.some(d => d.plan.planId === plan.planId && d.event.eventId !== e.eventId)) throw new Error('INVALID_PLAN');
      if (previous) data.drafts = data.drafts.filter(d => d.plan.planId !== previous.planId);
      data.drafts.push({ plan, event: e, state: 'pending', decisionId });
      if (!previous) this.recordEvent(data, e, result);
      if (confirmation) this.recordConfirmation(data, confirmation, result);
      if (suggestionId) {
        const suggestion = data.suggestions.find(s => s.id === suggestionId)!;
        suggestion.state = 'accept'; suggestion.responseEventId = e.eventId; suggestion.responseResult = result;
        data.feedback.push({ eventId: e.eventId, relatedDecisionId: decisionId, timestamp: this.stamp(), feedbackType: 'accepted', feedbackSource: 'phone', observationStatus: 'user_reported' });
      }
    });
    return this.log(e, result, this.deps.planner.info);
  }
  private async context(e: WorkflowEvent): Promise<WorkflowResult> {
    await this.log(e, { status: 'ESTIMATING' }, this.deps.estimator.info);
    const raw = await this.call(this.deps.estimator.info, () => this.deps.estimator.estimate(e));
    if (!validateContextFeatures(raw)) throw new Error('INVALID_CONTEXT');
    const features = raw as ContextFeatures;
    if (Date.parse(features.timestamp) > this.deps.now() || Date.parse(features.timestamp) < Date.parse(e.occurredAt)) throw new Error('INVALID_CONTEXT');
    const auth = await this.deps.authorize(e);
    if ((features.optionalLocationContext && !auth.scopes.includes('location')) || (features.optionalPhysiologicalFeatures && !auth.scopes.includes('physiology')) || (features.optionalBehaviorFeatures && !auth.scopes.includes('behavior_memory'))) throw new Error('INVALID_CONTEXT');
    const beforePolicy = await this.gate(e); if (beforePolicy) return { status: 'BLOCKED', reason: beforePolicy };
    await this.log(e, { status: 'DECIDING' }, this.deps.policy.info);
    const policy = await this.call(this.deps.policy.info, () => this.deps.policy.decide(features));
    if (!validateInterventionDecision(policy, features)) throw new Error('INVALID_DECISION');
    const d = policy as InterventionDecision;
    const afterPolicy = await this.gate(e); if (afterPolicy) return { status: 'BLOCKED', reason: afterPolicy };
    await this.log(e, { status: 'DECIDING', reason: d.reasonCodes.join(',') }, this.deps.policy.info);
    await this.deps.store.transact(state => { const audit = state.audit[state.audit.length - 1]; audit.contextId = features.contextId; audit.decisionId = d.decisionId; audit.evidenceReferences = d.evidenceReferences; });
    if (d.decision === 'ABSTAIN') return { status: 'ABSTAINED', reason: d.reasonCodes.join(',') };
    if (d.decision === 'DEFER') {
      if (!this.deps.schedulerAvailable) return { status: 'ABSTAINED', reason: 'SCHEDULER_UNAVAILABLE' };
      if (Date.parse(d.optionalDeferUntil!) >= Date.parse(e.expiresAt)) return { status: 'ABSTAINED', reason: 'DEFER_EXCEEDS_TTL' };
      const deferred = { status: 'DEFERRED', reason: d.reasonCodes.join(',') };
      await this.deps.store.transact(data => { data.schedules.push({ id: `defer_${d.decisionId}`, event: e, dueAt: d.optionalDeferUntil!, state: 'pending' }); this.recordEvent(data, e, deferred); });
      return deferred;
    }
    const data = await this.deps.store.read();
    const candidate = data.tasks.find(t => t.id === features.taskContext.candidateTaskId && !t.completed && t.focusStep.status !== 'completed' && (!features.taskContext.candidateStepId || data.drafts.find(p => p.plan.planId === t.planId)?.plan.firstStepId === features.taskContext.candidateStepId));
    const memory = features.taskContext.candidateReferenceId && auth.scopes.includes('behavior_memory') ? await this.deps.resolveCandidate?.(features.taskContext.candidateReferenceId) : undefined;
    const reliableMemory = memory?.userConfirmed && features.taskContext.candidateEvidenceIds.includes(memory.evidenceId) && memory.title.trim() ? memory : undefined;
    if (d.decision === 'INTERVENE' && !candidate && !reliableMemory) return { status: 'ABSTAINED', reason: 'NO_RELIABLE_CANDIDATE' };
    if (d.decision === 'ASK' && !auth.allowAsk) return { status: 'ABSTAINED', reason: 'ASK_NOT_ALLOWED' };
    const id = `suggestion_${d.decisionId}`;
    const result = { status: d.decision === 'ASK' ? 'AWAITING_CLARIFICATION' : 'PROPOSED', suggestionId: id, message: d.decision === 'ASK' ? '要一起确认下一步吗？' : candidate ? `要继续「${candidate.title}」的当前步骤吗？` : `要开始「${reliableMemory!.title}」吗？` };
    await this.deps.store.transact(state => { state.suggestions.push({ id, event: e, decision: d, candidateTaskId: candidate?.id, candidate: reliableMemory, state: 'pending' }); this.recordEvent(state, e, result); });
    return result;
  }
  respondToSuggestion(id: string, choice: 'accept'|'reject'|'pause'|'silent', eventId: string): Promise<WorkflowResult> {
    return this.serial(async () => {
      if (!eventId?.trim() || !['accept','reject','pause','silent'].includes(choice)) return { status: 'FAILED_SAFE', reason: 'INVALID_SUGGESTION_RESPONSE' };
      const suggestion = (await this.deps.store.read()).suggestions.find(s => s.id === id);
      if (!suggestion) return { status: 'CONFLICT', reason: 'SUGGESTION_NOT_PENDING' };
      const gate = await this.gate(suggestion.event); if (gate) return this.log(suggestion.event, { status: 'BLOCKED', reason: gate });
      if (suggestion.state !== 'pending') return suggestion.responseEventId === eventId && suggestion.state === choice && suggestion.responseResult ? suggestion.responseResult : { status: 'CONFLICT', reason: 'SUGGESTION_NOT_PENDING' };
      if (choice !== 'accept') {
        const result = { status: choice === 'pause' ? 'PAUSED' : 'DECLINED' };
        await this.deps.store.transact(data => {
          const current = data.suggestions.find(s => s.id === id)!; current.state = choice; current.responseEventId = eventId; current.responseResult = result;
          data.feedback.push({ eventId, relatedDecisionId: suggestion.decision.decisionId, timestamp: this.stamp(), feedbackType: choice === 'reject' ? 'rejected' : choice === 'pause' ? 'paused' : 'silent', feedbackSource: 'phone', observationStatus: choice === 'silent' ? 'not_observed' : 'user_reported' });
          data.controls.suppressed = true; if (choice === 'pause') this.pauseAll(data); data.schedules.forEach(s => s.state = 'cancelled');
        });
        return result;
      }
      const existing = (await this.deps.store.read()).tasks.find(t => t.id === suggestion.candidateTaskId);
      if (!existing && !suggestion.candidate) return { status: 'AWAITING_CLARIFICATION', reason: 'TASK_REQUIRED' };
      // Acceptance is an explicit user event, so B is not called a second time.
      const e: WorkflowEvent = { ...suggestion.event, eventId, channel: 'USER', source: 'phone', type: existing ? 'resume_task' : 'create_task', payload: existing ? { taskId: existing.id } : { title: suggestion.candidate!.title }, provenance: { adapterId: 'phone-ui', adapterVersion: '1.0' } };
      try { return await this.plan(e, existing, undefined, undefined, suggestion.decision.decisionId, undefined, id); } catch (error) { return this.fail(e, error); }
    });
  }
  confirm(c: ConfirmationEvent): Promise<WorkflowResult> { return this.serial(() => this.confirmInternal(c)); }
  private async confirmInternal(c: ConfirmationEvent): Promise<WorkflowResult> {
    if (!validateConfirmation(c)) return { status: 'FAILED_SAFE', reason: 'INVALID_CONFIRMATION' };
    const hash = fingerprint(c); const data = await this.deps.store.read();
    const draft = data.drafts.find(d => d.plan.planId === c.planId);
    if (!draft) return { status: 'CONFLICT', reason: 'STALE_PLAN' };
    try {
      const gate = await this.gate(draft.event);
      if (gate || data.controls.paused) return this.log(draft.event, { status: 'BLOCKED', reason: gate ?? 'USER_PAUSED' });
      const previous = data.confirmations.find(x => x.key === c.eventId);
      if (previous) return previous.fingerprint === hash ? previous.result : { status: 'CONFLICT', reason: 'CONFIRMATION_ID_REUSED' };
      if (draft.state !== 'pending' || draft.plan.planRevision !== c.planRevision) return { status: 'CONFLICT', reason: 'STALE_PLAN' };
      let result: WorkflowResult;
      if (c.choice === 'modify') result = await this.plan(draft.event, data.tasks.find(t => t.id === draft.plan.taskId), draft.plan, c.requestedEdit, draft.decisionId, c);
      else if (c.choice === 'reject' || c.choice === 'pause') {
        result = { status: c.choice === 'pause' ? 'PAUSED' : 'DECLINED' };
        await this.deps.store.transact(state => { state.drafts.find(d => d.plan.planId === c.planId)!.state = c.choice; if (c.choice === 'pause') this.pauseAll(state);
          state.feedback.push({ eventId: c.eventId, relatedDecisionId: draft.decisionId, timestamp: c.timestamp, feedbackType: c.choice === 'pause' ? 'paused' : 'rejected', feedbackSource: 'phone', observationStatus: 'user_reported' }); this.recordConfirmation(state, c, result); });
      } else {
        const task = materializeConfirmedPlan(draft.plan, this.deps.now(), data.tasks.find(t => t.id === draft.plan.taskId));
        const card = firstStepCard(task, draft.plan.firstStepId, draft.event.expiresAt);
        await this.log(draft.event, { status: 'PERSISTING' });
        await this.deps.store.transact(state => {
          const current = state.drafts.find(d => d.plan.planId === c.planId)!; current.state = 'accepted';
          state.tasks = [...state.tasks.filter(t => t.id !== task.id), task];
          state.outbox.push({ card, event: draft.event, status: 'SYNC_PENDING' });
          state.feedback.push({ eventId: c.eventId, relatedDecisionId: draft.decisionId, relatedActionId: task.focusStep.actionId, timestamp: c.timestamp, feedbackType: 'accepted', feedbackSource: 'phone', observationStatus: 'user_reported' });
          this.recordConfirmation(state, c, { status: 'SYNC_RETRYABLE', reason: 'DELIVERY_PENDING', card });
        });
        await this.log(draft.event, { status: 'SYNC_PENDING' });
        result = await this.deliver({ card, event: draft.event, status: 'SYNC_PENDING' });
      }
      await this.deps.store.transact(state => { this.recordConfirmation(state, c, result); });
      return this.log(draft.event, result);
    } catch (error) { return this.fail(draft.event, error); }
  }
  private async deliver(item: OutboxItem): Promise<WorkflowResult> {
    const gate = await this.gate(item.event); const state = await this.deps.store.read();
    const task = state.tasks.find(t => t.id === item.card.taskId);
    if (gate || state.controls.paused || !task || task.focusStep.actionId !== item.card.actionId || task.focusStep.revision !== item.card.actionRevision) {
      await this.deps.store.transact(d => { const current = d.outbox.find(o => o.card.cardId === item.card.cardId); if (current) current.status = 'CANCELLED'; });
      return { status: 'BLOCKED', reason: gate ?? 'STALE_OR_PAUSED_ACTION', card: item.card };
    }
    let status = 'SYNC_RETRYABLE'; let reason = 'SYNC_FAILED';
    try {
      const receipt = await this.call(this.deps.device.info, () => this.deps.device.send(item.card));
      if (!validateDeliveryReceipt(receipt, item.card.actionId)) throw new Error('INVALID_RECEIPT');
      const r = receipt as WorkflowData['receipts'][number];
      await this.deps.store.transact(d => { if (!d.receipts.some(x => x.receiptId === r.receiptId)) d.receipts.push(r); });
      status = r.status === 'delivered' ? 'DELIVERED' : 'SYNC_RETRYABLE'; reason = r.errorCode ?? r.status;
    } catch (error) { reason = error instanceof Error && error.message === 'INVALID_RECEIPT' ? 'INVALID_RECEIPT' : 'SYNC_FAILED'; }
    await this.deps.store.transact(d => { const current = d.outbox.find(o => o.card.cardId === item.card.cardId); if (current) current.status = status; });
    return { status, reason, card: item.card };
  }
  retrySync(): Promise<WorkflowResult[]> { return this.serial(async () => {
    const pending = (await this.deps.store.read()).outbox.filter(o => ['SYNC_PENDING','SYNC_RETRYABLE'].includes(o.status));
    const results: WorkflowResult[] = []; for (const item of pending) results.push(await this.log(item.event, await this.deliver(item))); return results;
  }); }
  runDue(): Promise<WorkflowResult[]> { return this.serial(async () => {
    const due = (await this.deps.store.read()).schedules.filter(s => s.state === 'pending' && Date.parse(s.dueAt) <= this.deps.now());
    const results: WorkflowResult[] = [];
    for (const job of due) {
      const result = await this.dispatchInternal({ ...job.event, eventId: job.id, occurredAt: job.dueAt });
      if (result.status !== 'FAILED_SAFE') await this.deps.store.transact(d => { d.schedules.find(s => s.id === job.id)!.state = 'consumed'; });
      results.push(result);
    }
    return results;
  }); }
  action(e: any): Promise<{ status: string; currentRevision?: number }> { return this.serial(async () => {
    if (!validateActionEvent(e)) return { status: 'invalid' };
    const before = await this.deps.store.read();
    const task = before.tasks.find(t => t.id === e.taskId);
    const authority = before.drafts.find(d => d.state === 'accepted' && d.plan.planId === task?.planId)?.event;
    if (!authority) return { status: 'missing' };
    const feedbackEvent: WorkflowEvent = { ...authority, type: 'card_feedback', channel: 'USER', source: e.origin, eventId: e.eventId,
      occurredAt: new Date(e.createdAt).toISOString(), payload: { taskId: e.taskId }, provenance: { adapterId: `${e.origin}-action`, adapterVersion: '2.1.0' } };
    if (await this.gate(feedbackEvent)) return { status: 'blocked' };
    return this.deps.store.transact(data => {
      if (data.feedback.some(f => f.eventId === e.eventId)) return { status: 'duplicate', currentRevision: task!.focusStep.revision };
      const result = applyActionEventToTasks(data.tasks, e);
      if (result.status === 'applied') {
        data.tasks = result.tasks;
        const draft = data.drafts.find(d => d.plan.taskId === e.taskId || d.plan.planId === data.tasks.find(t => t.id === e.taskId)?.planId);
        const step = draft?.plan.steps.find(s => s.stepId === draft.plan.firstStepId);
        if (step) step.status = e.type === 'complete' ? 'completed' : 'in_progress';
        data.feedback.push({ eventId: e.eventId, relatedActionId: e.actionId, timestamp: this.stamp(), feedbackType: e.type === 'complete' ? 'completion_reported' : 'start_confirmed', feedbackSource: e.origin, observationStatus: 'user_reported' });
      } else if (result.status === 'session_only') {
        if (e.type === 'pause') this.pauseAll(data); else if (e.type === 'resume') data.controls.paused = false;
        data.feedback.push({ eventId: e.eventId, relatedActionId: e.actionId, timestamp: this.stamp(), feedbackType: e.type === 'pause' ? 'paused' : 'start_confirmed', feedbackSource: e.origin, observationStatus: 'user_reported' });
      }
      return { status: result.status, currentRevision: result.currentRevision };
    });
  }); }
}
