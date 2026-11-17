import test from 'node:test';
import assert from 'node:assert/strict';
import { transitionFocusSession } from '../entry/src/main/ets/services/FocusSessionLogic.ts';

test('session follows the same action through start, pause, resume', () => {
  const running = transitionFocusSession(undefined, 'task-1', 'action-1', 'start', 10);
  assert.equal(running?.status, 'RUNNING');
  const paused = transitionFocusSession(running, 'task-1', 'action-1', 'pause', 20);
  assert.equal(paused?.status, 'PAUSED');
  const resumed = transitionFocusSession(paused, 'task-1', 'action-1', 'resume', 30);
  assert.equal(resumed?.status, 'RUNNING');
  assert.equal(resumed?.sessionId, running?.sessionId);
});

test('old action cannot control a newer session', () => {
  const running = transitionFocusSession(undefined, 'task-1', 'action-2', 'start', 10);
  assert.equal(transitionFocusSession(running, 'task-1', 'action-1', 'pause', 20), undefined);
});

test('replayed pause cannot pause a later resumed session', () => {
  const running = transitionFocusSession(undefined, 'task-1', 'action-1', 'start', 10);
  const paused = transitionFocusSession(running, 'task-1', 'action-1', 'pause', 20, 'pause-1');
  const resumed = transitionFocusSession(paused, 'task-1', 'action-1', 'resume', 30, 'resume-1');
  const replayed = transitionFocusSession(resumed, 'task-1', 'action-1', 'pause', 40, 'pause-1');
  assert.deepEqual(replayed, resumed);
});
