import test from 'node:test';
import assert from 'node:assert/strict';
import { applyActionEventToTasks } from '../entry/src/main/ets/services/ActionLogic.ts';

const initial = [{
  id: 'task-1', title: '写提纲', completed: false, createdAt: 1,
  focusStep: {
    taskId: 'task-1', actionId: 'action-1', text: '打开文档', status: 'ready',
    order: 0, updatedAt: 10, revision: 1, generationSource: 'rule'
  }
}];

const start = {
  eventId: 'event-start', taskId: 'task-1', actionId: 'action-1',
  baseRevision: 1, type: 'start', origin: 'phone', createdAt: 20
};

test('start and complete preserve action identity while increasing revision', () => {
  const started = applyActionEventToTasks(initial, start);
  assert.equal(started.status, 'applied');
  assert.equal(started.tasks[0].focusStep.actionId, 'action-1');
  assert.equal(started.tasks[0].focusStep.status, 'in_progress');
  assert.equal(started.tasks[0].focusStep.revision, 2);
  const done = applyActionEventToTasks(started.tasks, {
    ...start, eventId: 'event-done', type: 'complete', baseRevision: 2, createdAt: 30
  });
  assert.equal(done.status, 'applied');
  assert.equal(done.tasks[0].focusStep.status, 'completed');
  assert.equal(done.tasks[0].focusStep.actionId, 'action-1');
  assert.equal(done.tasks[0].focusStep.revision, 3);
});

test('replayed event is idempotent after persistence', () => {
  const started = applyActionEventToTasks(initial, start);
  const replayed = applyActionEventToTasks(structuredClone(started.tasks), start);
  assert.equal(replayed.status, 'duplicate');
  assert.deepEqual(replayed.tasks, started.tasks);
});

test('stale action and revision cannot change current task', () => {
  for (const event of [
    { ...start, actionId: 'old-action' },
    { ...start, baseRevision: 0 }
  ]) {
    const result = applyActionEventToTasks(initial, event);
    assert.equal(result.status, 'conflict');
    assert.deepEqual(result.tasks, initial);
  }
});

test('change without a real candidate and pause do not complete action', () => {
  const change = applyActionEventToTasks(initial, { ...start, type: 'change' });
  assert.equal(change.status, 'needs_step');
  assert.deepEqual(change.tasks, initial);
  const started = applyActionEventToTasks(initial, start);
  const pause = applyActionEventToTasks(started.tasks, {
    ...start, eventId: 'event-pause', type: 'pause', baseRevision: 2
  });
  assert.equal(pause.status, 'session_only');
  assert.deepEqual(pause.tasks, started.tasks);
  const resume = applyActionEventToTasks(started.tasks, {
    ...start, eventId: 'event-resume', type: 'resume', baseRevision: 2
  });
  assert.equal(resume.status, 'session_only');
  assert.deepEqual(resume.tasks, started.tasks);
});
