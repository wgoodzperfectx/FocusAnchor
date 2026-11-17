import test from 'node:test';
import assert from 'node:assert/strict';
import { selectUnambiguousTask } from '../entry/src/main/ets/pages/CurrentTaskSelection.ts';

const task = (id, status, completed = false) => ({ id, completed,
  focusStep: status ? { status } : undefined });

test('Home and Focus can display the same sole pending task before a step exists', () => {
  assert.equal(selectUnambiguousTask([task('a')])?.id, 'a');
});

test('an active action wins over an unstarted task without relying on list order', () => {
  assert.equal(selectUnambiguousTask([task('a'), task('b', 'in_progress')])?.id, 'b');
});

test('ambiguous active actions do not pick a priority winner', () => {
  assert.equal(selectUnambiguousTask([task('a', 'paused'), task('b', 'in_progress')]), undefined);
});

test('multiple unstarted tasks require explicit user selection', () => {
  assert.equal(selectUnambiguousTask([task('a'), task('b')]), undefined);
});
