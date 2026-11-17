import test from 'node:test';
import assert from 'node:assert/strict';
import { event, harness, confirmed, NOW } from './workflow-v2.1-fixtures.mjs';

test('WF-01 user-created task uses USER channel and bypasses B', async () => {
  const h = harness(); const r = await h.workflow.dispatch(event());
  assert.equal(r.status, 'AWAITING_CONFIRMATION'); assert.equal(h.planner.calls, 1); assert.equal(h.policy.calls, 0);
});
test('WF-02 multi-step plan stays draft until confirmed then presents only first step', async () => {
  const h = harness(); const r = await h.workflow.dispatch(event());
  assert.equal(r.plan.steps.length, 3); assert.equal((await h.store.read()).tasks.length, 0);
  const accepted = await h.workflow.confirm({ eventId: 'accept', actor: 'user', choice: 'accept', planId: r.plan.planId, planRevision: 1, timestamp: new Date(NOW).toISOString() });
  assert.equal(accepted.status, 'DELIVERED'); assert.equal(accepted.card.action, r.plan.steps[0].text);
  const data = await h.store.read(); assert.equal(data.tasks.length, 1); assert.equal(data.tasks[0].focusStep.actionId, accepted.card.actionId);
  assert.equal(data.feedback.filter(f => f.feedbackType === 'start_confirmed').length, 0);
});
test('WF-03 user rejection creates no Task or Action and sends nothing', async () => {
  const h = harness(); const r = await h.workflow.dispatch(event());
  const rejected = await h.workflow.confirm({ eventId: 'reject', actor: 'user', choice: 'reject', planId: r.plan.planId, planRevision: 1, timestamp: new Date(NOW).toISOString() });
  assert.equal(rejected.status, 'DECLINED'); assert.equal((await h.store.read()).tasks.length, 0); assert.equal(h.device.calls, 0);
});
test('WF-04 modification increments plan revision and requires fresh confirmation', async () => {
  const h = harness(); const r = await h.workflow.dispatch(event());
  const modified = await h.workflow.confirm({ eventId: 'edit', actor: 'user', choice: 'modify', requestedEdit: '先打开参考文献', planId: r.plan.planId, planRevision: 1, timestamp: new Date(NOW).toISOString() });
  assert.equal(modified.plan.planRevision, 2); assert.equal((await h.store.read()).tasks.length, 0);
  assert.equal((await h.workflow.confirm({ eventId: 'stale', actor: 'user', choice: 'accept', planId: r.plan.planId, planRevision: 1, timestamp: new Date(NOW).toISOString() })).status, 'CONFLICT');
  const done = await h.workflow.confirm({ eventId: 'new', actor: 'user', choice: 'accept', planId: r.plan.planId, planRevision: 2, timestamp: new Date(NOW).toISOString() });
  assert.equal(done.card.action, '先打开参考文献');
});
test('WF-05 thoughts stay in separate sandbox and never implicitly become tasks', async () => {
  const h = harness();
  await h.workflow.dispatch(event('capture_thought', { payload: { text: '买书', storageConfirmed: true } }));
  assert.equal((await h.store.read()).sandbox.length, 1); assert.equal((await h.store.read()).tasks.length, 0); assert.equal(h.planner.calls, 0);
  await h.workflow.dispatch(event('capture_thought', { eventId: 'no-storage', payload: { text: '不要保存', storageConfirmed: false } }));
  assert.equal((await h.store.read()).sandbox.length, 1);
});
test('WF-06 unauthorized context event is blocked before A/B', async () => {
  const h = harness(); h.auth.granted = false;
  assert.equal((await h.workflow.dispatch(event('time_due'))).status, 'BLOCKED');
  assert.equal(h.estimator.calls, 0); assert.equal(h.policy.calls, 0);
});
test('WF-07 quiet hours block proactive processing and delivery', async () => {
  const h = harness(); h.auth.quietHours = true;
  assert.equal((await h.workflow.dispatch(event('time_due'))).reason, 'QUIET_HOURS');
  assert.equal(h.policy.calls, 0); assert.equal(h.device.calls, 0);
});
test('WF-08 INTERVENE proposes a traceable existing step and waits for acceptance', async () => {
  const h = harness(); await confirmed(h); const before = (await h.store.read()).tasks[0];
  h.estimator.candidateTaskId = before.id; h.policy.decision = 'INTERVENE';
  const r = await h.workflow.dispatch(event('time_due'));
  assert.equal(r.status, 'PROPOSED'); assert.equal(h.device.calls, 1); // initial confirmed task only
  const resumed = await h.workflow.respondToSuggestion(r.suggestionId, 'accept', 'suggestion-accept');
  assert.equal(resumed.status, 'AWAITING_CONFIRMATION');
  const done = await h.workflow.confirm({ eventId: 'resume-confirm', actor: 'user', choice: 'accept', planId: resumed.plan.planId, planRevision: resumed.plan.planRevision, timestamp: new Date(NOW).toISOString() });
  assert.equal(done.card.actionId, before.focusStep.actionId); assert.equal((await h.store.read()).tasks.length, 1);
});
test('WF-09 DEFER creates no notification and rechecks authorization at scheduled time', async () => {
  const h = harness(); h.policy.decision = 'DEFER';
  const r = await h.workflow.dispatch(event('time_due')); assert.equal(r.status, 'DEFERRED'); assert.equal(h.device.calls, 0);
  h.clock.advance(30000); h.auth.granted = false;
  assert.equal((await h.workflow.runDue())[0].status, 'BLOCKED'); assert.equal(h.policy.calls, 1);
});
test('WF-10 ABSTAIN ends event without notice, clarification or action', async () => {
  const h = harness(); h.policy.decision = 'ABSTAIN';
  assert.equal((await h.workflow.dispatch(event('time_due'))).status, 'ABSTAINED');
  const d = await h.store.read(); assert.equal(d.tasks.length, 0); assert.equal(d.suggestions.length, 0); assert.equal(h.device.calls, 0);
});
test('WF-11 ASK is controlled and silence suppresses further proactive questions', async () => {
  const h = harness(); h.policy.decision = 'ASK';
  const r = await h.workflow.dispatch(event('time_due')); assert.equal(r.status, 'AWAITING_CLARIFICATION');
  await h.workflow.respondToSuggestion(r.suggestionId, 'silent', 'silent-1');
  assert.equal((await h.workflow.dispatch(event('time_due', { eventId: 'later' }))).status, 'BLOCKED');
  assert.equal(h.policy.calls, 1);
});
test('WF-12 invalid schema, thrown errors and timeouts fail safely at every model boundary', async () => {
  for (const provider of ['planner', 'estimator', 'policy']) for (const mode of ['invalid', 'error', 'timeout']) {
    const h = harness(); h[provider].mode = mode;
    const r = await h.workflow.dispatch(event(provider === 'planner' ? 'create_task' : 'time_due'));
    assert.equal(r.status, 'FAILED_SAFE', `${provider}/${mode}`); assert.ok(r.reason);
    const d = await h.store.read(); assert.equal(d.tasks.length, 0); assert.equal(h.device.calls, 0);
    assert.ok(d.audit.some(a => a.correlationId && a.reason === r.reason));
  }
});
test('WF-13 offline sync keeps durable local task and retries with same action identity', async () => {
  const h = harness(); h.device.mode = 'offline'; const r = await confirmed(h);
  assert.equal(r.status, 'SYNC_RETRYABLE'); const d = await h.store.read(); assert.equal(d.tasks.length, 1);
  h.device.mode = 'normal'; const recovered = await h.workflow.retrySync();
  assert.equal(recovered[0].status, 'DELIVERED'); assert.equal(recovered[0].card.actionId, r.card.actionId);
});
test('WF-14 repeated events and confirmation are idempotent including concurrent dispatch', async () => {
  const h = harness(); const [a,b] = await Promise.all([h.workflow.dispatch(event()), h.workflow.dispatch(event())]);
  assert.equal(a.plan.planId, b.plan.planId); assert.equal(h.planner.calls, 1);
  const confirmation = { eventId: 'once', actor: 'user', choice: 'accept', planId: a.plan.planId, planRevision: 1, timestamp: new Date(NOW).toISOString() };
  await h.workflow.confirm(confirmation); await h.workflow.confirm(confirmation);
  assert.equal((await h.store.read()).tasks.length, 1); assert.equal(h.device.calls, 1);
  assert.equal((await h.workflow.dispatch(event('create_task', { payload: { title: 'different' } }))).status, 'CONFLICT');
});
test('WF-15 watch feedback updates matching action after persistence and rejects stale revision', async () => {
  const h = harness(); const r = await confirmed(h); const action = r.card;
  const op = { eventId: 'watch-start', taskId: action.taskId, actionId: action.actionId, baseRevision: 1, type: 'start', origin: 'watch', createdAt: NOW };
  assert.equal((await h.workflow.action(op)).status, 'applied');
  const complete = { ...op, eventId: 'watch-done', baseRevision: 2, type: 'complete' };
  assert.equal((await h.workflow.action(complete)).status, 'applied');
  assert.equal((await h.workflow.action(complete)).status, 'duplicate');
  assert.equal((await h.store.read()).tasks[0].focusStep.revision, 3);
  assert.equal((await h.workflow.action({ ...complete, eventId: 'stale', baseRevision: 1 })).status, 'conflict');
  assert.ok((await h.store.read()).feedback.some(f => f.feedbackType === 'completion_reported'));
});
test('WF-16 missing signals remain absent and INTERVENE without candidate abstains', async () => {
  const h = harness(); h.policy.decision = 'INTERVENE';
  const r = await h.workflow.dispatch(event('time_due')); assert.equal(r.status, 'ABSTAINED');
  assert.equal(h.estimator.lastResult.optionalLocationContext, undefined); assert.equal(h.estimator.lastResult.optionalPhysiologicalFeatures, undefined);
  assert.ok(h.estimator.lastResult.missingFields.includes('optionalPhysiologicalFeatures')); assert.equal((await h.store.read()).tasks.length, 0);
});
test('WF-17 revocation invalidates pending confirmations, scheduled checks and offline deliveries', async () => {
  const h = harness(); const draft = await h.workflow.dispatch(event()); h.auth.granted = false;
  const r = await h.workflow.confirm({ eventId: 'revoked', actor: 'user', choice: 'accept', planId: draft.plan.planId, planRevision: 1, timestamp: new Date(NOW).toISOString() });
  assert.equal(r.status, 'BLOCKED'); assert.equal((await h.store.read()).tasks.length, 0);
  const h2 = harness(); h2.device.mode = 'offline'; await confirmed(h2); h2.auth.granted = false;
  assert.equal((await h2.workflow.retrySync())[0].status, 'BLOCKED'); assert.equal(h2.device.calls, 1);
});
