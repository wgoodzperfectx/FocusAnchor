import test from 'node:test';
import assert from 'node:assert/strict';
import { materializeTaskAction, normalizeFocusAction } from '../entry/src/main/ets/services/ActionLogic.ts';

const legacyTask = {
  id: 'task-42', title: '整理材料', completed: false, createdAt: 10,
  focusStep: { text: '打开文档', status: 'ready', updatedAt: 1234 }
};

test('legacy step gets a stable identity and explicit source', () => {
  const first = normalizeFocusAction(legacyTask);
  const second = normalizeFocusAction(structuredClone(legacyTask));
  assert.deepEqual(first, second);
  assert.equal(first.taskId, 'task-42');
  assert.equal(first.revision, 1);
  assert.equal(first.order, 0);
  assert.equal(first.generationSource, 'legacy');
  assert.ok(first.actionId.length > 0);
});

test('missing step never creates a placeholder action', () => {
  assert.equal(normalizeFocusAction({ ...legacyTask, focusStep: undefined }), undefined);
  assert.equal(normalizeFocusAction({ ...legacyTask, completed: true }), undefined);
});

test('legacy paused step is active action state', () => {
  const action = normalizeFocusAction({
    ...legacyTask, focusStep: { ...legacyTask.focusStep, status: 'paused' }
  });
  assert.equal(action.status, 'in_progress');
});

test('materializing a legacy step preserves task fields and does not mutate input', () => {
  const original = structuredClone(legacyTask);
  const migrated = materializeTaskAction(original);
  assert.equal(migrated.title, '整理材料');
  assert.equal(migrated.focusStep.actionId, normalizeFocusAction(original).actionId);
  assert.equal(original.focusStep.actionId, undefined);
});
