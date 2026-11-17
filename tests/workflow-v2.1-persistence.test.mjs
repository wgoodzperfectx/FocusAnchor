import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rename, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { WorkflowV21SnapshotStore } from '../entry/src/main/ets/services/WorkflowV21SnapshotStore.ts';
import { harness, confirmed, event } from './workflow-v2.1-fixtures.mjs';

async function disk(t) {
  const dir = await mkdtemp(join(tmpdir(), 'focusanchor-v21-')); t.after(() => rm(dir, { recursive: true, force: true }));
  const path = join(dir, 'workflow-v21.json');
  const io = { read: async () => { try { return await readFile(path, 'utf8'); } catch (e) { if (e.code === 'ENOENT') return undefined; throw e; } },
    replace: async text => { await writeFile(path + '.tmp', text, 'utf8'); await rename(path + '.tmp', path); } };
  return { io, path };
}
test('durable snapshot: restart preserves Task/Action/Outbox and retries same identity', async t => {
  const { io, path } = await disk(t); const h = harness(new WorkflowV21SnapshotStore(io));
  h.device.mode = 'offline'; const result = await confirmed(h);
  const stored = JSON.parse(await readFile(path, 'utf8')); assert.equal(stored.tasks.length, 1);
  const restarted = harness(new WorkflowV21SnapshotStore(io));
  const results = await restarted.workflow.retrySync(); assert.equal(results[0].status, 'DELIVERED');
  assert.equal(results[0].card.actionId, result.card.actionId);
  const replay = await restarted.workflow.dispatch(event()); assert.equal(restarted.planner.calls, 0); assert.equal(replay.plan.planId, stored.drafts[0].plan.planId);
});
test('durable snapshot: failed replacement cannot mutate canonical memory or publish an action', async t => {
  const { io } = await disk(t); let fail = false;
  const h = harness(new WorkflowV21SnapshotStore({ ...io, replace: async text => { if (fail) throw new Error('STORE_WRITE_FAILED'); await io.replace(text); } }));
  const draft = await h.workflow.dispatch(event()); fail = true;
  const result = await h.workflow.confirm(await h.confirmation.respond(draft.plan, 'accept', new Date(h.clock.now()).toISOString()));
  assert.equal(result.status, 'FAILED_SAFE'); assert.equal(h.device.calls, 0);
  assert.equal((await new WorkflowV21SnapshotStore(io).read()).tasks.length, 0);
});
test('durable snapshot: corrupted file fails closed instead of overwriting with empty data', async t => {
  const { io, path } = await disk(t); await writeFile(path, '{broken', 'utf8');
  const h = harness(new WorkflowV21SnapshotStore(io));
  assert.equal((await h.workflow.dispatch(event())).status, 'FAILED_SAFE');
  assert.equal(await readFile(path, 'utf8'), '{broken'); assert.equal(h.device.calls, 0);
});
