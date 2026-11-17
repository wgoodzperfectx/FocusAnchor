import test from 'node:test';
import assert from 'node:assert/strict';
import { event, harness, confirmed, NOW } from './workflow-v2.1-fixtures.mjs';

for (const id of ['W01','W02','I01','I02']) test(`LEGACY-${id} thought sandbox honors storage choice without creating a Task`, async () => {
  const h = harness(); const store = id !== 'I02';
  if (id === 'W01' || id === 'I01' || id === 'I02') await confirmed(h);
  const before = (await h.store.read()).tasks;
  const result = await h.workflow.dispatch(event('capture_thought', { payload: { text: id === 'I02' ? '不要保存，只提醒我继续做当前这一步' : '我突然想到要买书，先帮我记下，我要继续写报告', storageConfirmed: store } }));
  assert.equal(result.status, store ? 'SANDBOXED' : 'NOT_STORED');
  assert.equal((await h.store.read()).sandbox.length, store ? 1 : 0);
  assert.deepEqual((await h.store.read()).tasks, before); assert.equal(h.policy.calls, 0);
  assert.equal(result.message.includes('旅行攻略'), false);
});
for (const id of ['W03','I03']) test(`LEGACY-${id} unavailable task history asks without inventing a task`, async () => {
  const h = harness(); const result = await h.workflow.dispatch(event('resume_task', { payload: { text: '我刚才在做什么' } }));
  assert.equal(result.status, 'AWAITING_CLARIFICATION'); assert.equal(h.planner.calls, 0); assert.equal((await h.store.read()).tasks.length, 0);
});
test('LEGACY-I04 authorized recall is a correctable draft before execution', async () => {
  const h = harness(); const task = await confirmed(h);
  const result = await h.workflow.dispatch(event('resume_task', { payload: { taskId: task.card.taskId, text: '帮我回到刚才的任务' } }));
  assert.equal(result.status, 'AWAITING_CONFIRMATION'); assert.equal(result.plan.taskId, task.card.taskId);
  assert.equal(h.device.calls, 1);
});
for (const id of ['W04','I06']) test(`LEGACY-${id} companion pause stops future nudges`, async () => {
  const h = harness();
  assert.equal((await h.workflow.dispatch(event('focus_companion', { payload: { companionAction: 'pause' } }))).status, 'PAUSED');
  assert.equal((await h.workflow.dispatch(event('time_due'))).reason, 'USER_SUPPRESSED'); assert.equal(h.device.calls, 0);
});
test('LEGACY-I05 companion support follows user choice without medical claims', async () => {
  const h = harness(); const result = await h.workflow.dispatch(event('focus_companion', { payload: { text: '陪我专注二十分钟，提醒轻一点', companionAction: 'start' } }));
  assert.equal(result.status, 'COMPANION_CONFIGURED'); assert.equal(h.planner.calls, 0); assert.equal(h.policy.calls, 0);
});
for (const id of ['W05','W06']) test(`LEGACY-${id} completion records user feedback without unverified haptics`, async () => {
  const h = harness(); const result = await confirmed(h);
  await h.workflow.action({ eventId: `done-${id}`, taskId: result.card.taskId, actionId: result.card.actionId, baseRevision: 1, type: 'complete', origin: 'card', createdAt: NOW });
  const d = await h.store.read(); assert.equal(d.tasks[0].focusStep.status, 'completed');
  assert.equal(d.feedback.filter(f => f.feedbackType === 'completion_reported').length, 1);
  assert.equal(h.device.calls, 1); // completion itself sends no device/haptic command
});
test('LEGACY-W07 unauthorized device signal is ignored', async () => {
  const h = harness(); h.auth.granted = false;
  assert.equal((await h.workflow.dispatch(event('physiology_abstract'))).status, 'BLOCKED'); assert.equal(h.policy.calls, 0);
});
for (const [id, text] of [['W08','我想伤害自己'],['S01','我想伤害自己'],['W09','我心率很高，告诉我是否要吃药'],['S02','我心率很高，帮我决定要不要吃药']]) test(`LEGACY-${id} safety stops ordinary focus support`, async () => {
  const h = harness(); const result = await h.workflow.dispatch(event('capture_thought', { payload: { text, storageConfirmed: true } }));
  assert.equal(result.reason, 'SAFETY_HANDOFF'); const d = await h.store.read(); assert.equal(d.sandbox.length, 0); assert.equal(d.tasks.length, 0); assert.equal(h.planner.calls, 0);
});
test('LEGACY-P01 no authorization means no history lookup or model call', async () => {
  const h = harness(); h.auth.granted = false;
  assert.equal((await h.workflow.dispatch(event('resume_task'))).status, 'BLOCKED'); assert.equal(h.planner.calls, 0);
});
