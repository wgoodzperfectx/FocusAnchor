import test from 'node:test';
import assert from 'node:assert/strict';
import { WorkflowV21 } from '../entry/src/main/ets/services/WorkflowV21Router.ts';
import { event, harness, confirmed, NOW } from './workflow-v2.1-fixtures.mjs';

test('review: Planner cannot attach a new request to an unrelated existing task', async () => {
  const h = harness(); await confirmed(h); const before = await h.store.read(); const old = before.tasks[0];
  const plan = h.planner.plan.bind(h.planner);
  h.planner.plan = async input => ({ ...await plan(input), taskId: old.id });
  const r = await h.workflow.dispatch(event('create_task', { eventId: 'new-goal', payload: { title: '新目标' } }));
  assert.equal(r.status, 'FAILED_SAFE'); assert.deepEqual((await h.store.read()).tasks, before.tasks);
});
test('review: explicit new user task can proceed after pause while proactive nudges stay suppressed', async () => {
  const h = harness(); const draft = await h.workflow.dispatch(event());
  await h.workflow.confirm({ eventId: 'pause', actor: 'user', choice: 'pause', planId: draft.plan.planId, planRevision: 1, timestamp: new Date(NOW).toISOString() });
  const next = await confirmed(h, event('create_task', { eventId: 'new-user-request', payload: { title: '下一项' } }));
  assert.equal(next.status, 'DELIVERED');
  assert.equal((await h.workflow.dispatch(event('time_due'))).reason, 'USER_SUPPRESSED');
});
test('review: interruption at event ledger cannot create duplicate drafts after restart', async () => {
  const h = harness(); const transact = h.store.transact.bind(h.store); let armed = true;
  h.store.transact = work => transact(data => {
    const hadDraft = data.drafts.length > 0; const processed = data.processed.length; const result = work(data);
    if (armed && hadDraft && data.processed.length > processed) { armed = false; throw new Error('STORE_WRITE_FAILED'); }
    return result;
  });
  await h.workflow.dispatch(event());
  const restarted = new WorkflowV21(h.deps); const replay = await restarted.dispatch(event());
  assert.equal(replay.status, 'AWAITING_CONFIRMATION'); assert.equal((await h.store.read()).drafts.length, 1); assert.equal(h.planner.calls, 1);
});
test('review: confirmation identity is committed with Action so interrupted replay is recoverable', async () => {
  const h = harness(); const draft = await h.workflow.dispatch(event());
  const c = await h.confirmation.respond(draft.plan, 'accept', new Date(NOW).toISOString());
  const transact = h.store.transact.bind(h.store); let armed = true;
  h.store.transact = work => transact(data => {
    const hadTask = data.tasks.length > 0; const confirms = data.confirmations.length; const result = work(data);
    if (armed && hadTask && data.confirmations.length > confirms) { armed = false; throw new Error('STORE_WRITE_FAILED'); }
    return result;
  });
  await h.workflow.confirm(c); const restarted = new WorkflowV21(h.deps); const replay = await restarted.confirm(c);
  assert.ok(['DELIVERED','SYNC_RETRYABLE'].includes(replay.status), replay.status);
  assert.equal((await h.store.read()).tasks.length, 1); assert.equal(h.device.calls, 1);
});
test('review: failed suggestion planning remains retryable with the same response ID', async () => {
  const h = harness(); await confirmed(h); h.estimator.candidateTaskId = (await h.store.read()).tasks[0].id; h.policy.decision = 'INTERVENE';
  const suggestion = await h.workflow.dispatch(event('time_due')); h.planner.mode = 'error';
  assert.equal((await h.workflow.respondToSuggestion(suggestion.suggestionId, 'accept', 'accept-suggestion')).status, 'FAILED_SAFE');
  h.planner.mode = 'normal';
  const retry = await h.workflow.respondToSuggestion(suggestion.suggestionId, 'accept', 'accept-suggestion');
  assert.equal(retry.status, 'AWAITING_CONFIRMATION');
  assert.equal((await h.store.read()).feedback.filter(f => f.eventId === 'accept-suggestion').length, 1);
});
test('review: scheduled model failure does not permanently consume the check', async () => {
  const h = harness(); h.policy.decision = 'DEFER'; await h.workflow.dispatch(event('time_due')); h.clock.advance(30000);
  h.estimator.mode = 'error'; assert.equal((await h.workflow.runDue())[0].status, 'FAILED_SAFE');
  h.estimator.mode = 'normal'; h.policy.decision = 'ABSTAIN';
  assert.equal((await h.workflow.runDue())[0].status, 'ABSTAINED');
});
test('review: revoked authorization or untrusted source blocks delayed watch operations', async () => {
  const h = harness(); const r = await confirmed(h); h.auth.granted = false;
  const op = { eventId: 'delayed-watch', taskId: r.card.taskId, actionId: r.card.actionId, baseRevision: 1, type: 'start', origin: 'watch', createdAt: NOW };
  assert.equal((await h.workflow.action(op)).status, 'blocked');
  h.auth.granted = true; h.auth.validSource = false; assert.equal((await h.workflow.action(op)).status, 'blocked');
  assert.equal((await h.store.read()).tasks[0].focusStep.revision, 1);
});
