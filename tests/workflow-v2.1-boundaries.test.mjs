import test from 'node:test';
import assert from 'node:assert/strict';
import { event, harness, confirmed, NOW } from './workflow-v2.1-fixtures.mjs';

test('revoked authorization cannot replay cached draft or accepted confirmation', async () => {
  const h = harness(); const r = await h.workflow.dispatch(event());
  const c = await h.confirmation.respond(r.plan, 'accept', new Date(NOW).toISOString()); await h.workflow.confirm(c);
  h.auth.granted = false;
  assert.equal((await h.workflow.dispatch(event())).status, 'BLOCKED');
  assert.equal((await h.workflow.confirm(c)).status, 'BLOCKED');
});
test('user pause remains effective without authorization and cancels delayed reminders', async () => {
  const h = harness(); h.policy.decision = 'DEFER'; await h.workflow.dispatch(event('time_due')); h.auth.granted = false;
  assert.equal((await h.workflow.dispatch(event('focus_companion', { payload: { companionAction: 'pause' } }))).status, 'PAUSED');
  assert.equal((await h.store.read()).schedules[0].state, 'cancelled');
});
test('unavailable provider and invalid delivery response cannot claim success', async () => {
  const h = harness(); h.planner.info.capability = 'planned';
  assert.equal((await h.workflow.dispatch(event())).reason, 'PROVIDER_UNAVAILABLE'); assert.equal(h.planner.calls, 0);
  const h2 = harness(); h2.device.mode = 'invalid';
  assert.equal((await confirmed(h2)).reason, 'INVALID_RECEIPT'); assert.equal((await h2.store.read()).tasks.length, 1);
});
test('expired or untrusted context cannot call models; no scheduler safely abstains', async () => {
  const h = harness(); h.clock.advance(60000);
  assert.equal((await h.workflow.dispatch(event('time_due'))).status, 'BLOCKED'); assert.equal(h.estimator.calls, 0);
  const h2 = harness(); h2.auth.validSource = false;
  assert.equal((await h2.workflow.dispatch(event('time_due'))).reason, 'UNTRUSTED_SOURCE');
  const h3 = harness(); h3.deps.schedulerAvailable = false; h3.policy.decision = 'DEFER';
  assert.equal((await h3.workflow.dispatch(event('time_due'))).reason, 'SCHEDULER_UNAVAILABLE');
});
test('candidate activation requires user-confirmed memory and still waits for plan confirmation', async () => {
  const h = harness(); h.auth.scopes.push('behavior_memory'); h.estimator.candidateReferenceId = 'memory-1'; h.policy.decision = 'INTERVENE';
  h.candidates.push({ referenceId: 'memory-1', title: '复习英语', evidenceId: 'memory:memory-1', userConfirmed: true });
  const r = await h.workflow.dispatch(event('time_due')); assert.equal(r.status, 'PROPOSED'); assert.equal((await h.store.read()).tasks.length, 0);
  const draft = await h.workflow.respondToSuggestion(r.suggestionId, 'accept', 'activation');
  assert.equal(draft.status, 'AWAITING_CONFIRMATION'); assert.equal(draft.plan.title, '复习英语'); assert.equal((await h.store.read()).tasks.length, 0);
});
test('unsafe Planner output and invented existing step are rejected', async () => {
  const h = harness(); const base = h.planner.plan.bind(h.planner);
  h.planner.plan = async input => { const p = await base(input); p.steps[0].text = '停止吃药'; return p; };
  assert.equal((await h.workflow.dispatch(event())).status, 'FAILED_SAFE'); assert.equal((await h.store.read()).tasks.length, 0);
  const h2 = harness(); const done = await confirmed(h2); h2.estimator.candidateTaskId = done.card.taskId;
  const estimate = h2.estimator.estimate.bind(h2.estimator);
  h2.estimator.estimate = async e => { const c = await estimate(e); c.taskContext.candidateStepId = 'not-current'; return c; };
  h2.policy.decision = 'INTERVENE'; assert.equal((await h2.workflow.dispatch(event('time_due'))).status, 'ABSTAINED');
});
test('rejection or pause of accepted proactive suggestion blocks any subsequent delayed nudge', async () => {
  const h = harness(); await confirmed(h); h.estimator.candidateTaskId = (await h.store.read()).tasks[0].id; h.policy.decision = 'INTERVENE';
  const r = await h.workflow.dispatch(event('time_due')); await h.workflow.respondToSuggestion(r.suggestionId, 'reject', 'decline');
  assert.equal((await h.workflow.dispatch(event('time_due', { eventId: 'later' }))).reason, 'USER_SUPPRESSED');
});
test('workflow records actual model and persistence transitions with trace references', async () => {
  const h = harness(); await confirmed(h);
  let audit = (await h.store.read()).audit.map(a => a.status);
  for (const state of ['RECEIVED','PLANNING','AWAITING_CONFIRMATION','PERSISTING','SYNC_PENDING','DELIVERED']) assert.ok(audit.includes(state), state);
  h.policy.decision = 'ABSTAIN'; await h.workflow.dispatch(event('time_due'));
  const d = await h.store.read(); audit = d.audit.map(a => a.status);
  assert.ok(audit.includes('ESTIMATING')); assert.ok(d.audit.some(a => a.decisionId && a.contextId));
});
test('existing App task identity supplied by explicit user input survives planning', async () => {
  const h = harness(); const r = await confirmed(h, event('create_task', { payload: { title: '旧任务', taskId: 'app-existing' } }));
  assert.equal(r.card.taskId, 'app-existing');
});
