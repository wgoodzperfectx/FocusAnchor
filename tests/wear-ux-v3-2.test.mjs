import test from 'node:test';
import assert from 'node:assert/strict';
import * as ui from '../wear/src/main/ets/services/WearUiState.ts';
import { selectCurrentAction, selectCompletedAction, primaryStepEvent, monitorVisualId, monitorSourceLabel,
  monitorStateLabel,
  resolveMonitorSnapshot, flashTransportState, flashUiLabel } from
  '../wear/src/main/ets/services/WearUiState.ts';
import { WearFlashQueue } from '../wear/src/main/ets/services/WearFlashNoteService.ts';
import { WearSyncQueue } from '../wear/src/main/ets/services/WearSyncQueue.ts';

const task = (id, actionId, status = 'ready') => ({ id, completed: false,
  focusStep: actionId ? { actionId, revision: 1, text: `Step ${id}`, status } : undefined });

test('empty, incomplete and ambiguous phone projections never invent a current step', () => {
  assert.equal(selectCurrentAction([]), undefined);
  assert.equal(selectCurrentAction([task('a')]), undefined);
  assert.equal(selectCurrentAction([task('a', 'a1'), task('b', 'b1')]), undefined);
});

test('a confirmed action ID selects only its matching phone projection', () => {
  const a = task('a', 'a1');
  const b = task('b', 'b1', 'in_progress');
  assert.equal(selectCurrentAction([a, b], 'a1'), a);
  assert.equal(selectCurrentAction([a, b], 'missing'), undefined);
  assert.equal(selectCurrentAction([a]), a);
  const stale = { ...a, focusStep: { ...a.focusStep, revision: undefined } };
  assert.equal(selectCurrentAction([stale], 'a1'), undefined);
  assert.equal(selectCurrentAction([a, { ...a, id: 'duplicate' }], 'a1'), undefined);
});

test('completion art requires the phone to confirm the exact Action', () => {
  const done = { ...task('a', 'a1', 'completed'), completed: true };
  assert.equal(selectCurrentAction([done], 'a1'), undefined);
  assert.equal(selectCompletedAction([done], 'a1'), done);
  assert.equal(selectCompletedAction([done]), undefined);
  assert.equal(selectCompletedAction([done], 'other'), undefined);
  assert.equal(selectCompletedAction([done, { ...done, id: 'duplicate' }], 'a1'), undefined);
});

test('primary action is start, pause or resume; completion stays secondary', () => {
  assert.equal(primaryStepEvent('ready', false), 'start');
  assert.equal(primaryStepEvent('in_progress', false), 'pause');
  assert.equal(primaryStepEvent('in_progress', true), 'resume');
  assert.equal(primaryStepEvent('paused', false), 'resume');
});

test('start, pause, resume and complete become distinct action events for the same Action', () => {
  const queue = new WearSyncQueue();
  const types = ['start', 'pause', 'resume', 'complete'];
  types.forEach((type, index) => queue.enqueueOperation('t1', 'a1', 7, type, index + 1, 100 + index));
  assert.deepEqual(queue.pending().map(event => event.type), types);
  assert.ok(queue.pending().every(event => event.actionId === 'a1' && event.baseRevision === 7));
});

test('all six monitoring states have a distinct visual; unknown does not imply monitoring', () => {
  const states = ['CONNECTING', 'READING', 'MONITORING', 'SIGNAL_UNSTABLE', 'RECONNECTING', 'STOPPED'];
  assert.equal(new Set(states.map(monitorVisualId)).size, 6);
  for (const state of states) {
    assert.equal(resolveMonitorSnapshot({ state, source: 'REAL', updatedAt: 900 }, 1000).state, state);
    assert.ok(monitorStateLabel(state, true).length > 0);
  }
  assert.equal(resolveMonitorSnapshot(undefined, 1000).state, 'UNKNOWN');
  assert.equal(resolveMonitorSnapshot({ state: 'MONITORING', source: 'REAL', updatedAt: 0 }, 100000).state,
    'UNKNOWN');
  assert.equal(monitorSourceLabel('SIMULATED', true), '模拟数据 · 不推断专注');
  assert.equal(monitorSourceLabel('UNAVAILABLE', true), '设备数据未提供');
  assert.equal(monitorVisualId('UNKNOWN'), 'status_ready');
});

test('the eight interaction states and three user states resolve to their formal character assets', () => {
  assert.equal(typeof ui.interactionVisualId, 'function');
  assert.equal(typeof ui.companionVisualId, 'function');
  assert.deepEqual(['IDLE', 'LISTENING', 'BREAKING_DOWN', 'AWAITING_CONFIRMATION', 'FIRST_STEP',
    'IN_PROGRESS', 'PAUSED', 'STEP_COMPLETE'].map(state => ui.interactionVisualId(state)), [
    'status_ready', 'status_listening', 'status_breaking_down', 'status_awaiting_confirmation',
    'status_first_step', 'status_in_progress', 'status_paused', 'status_step_complete'
  ]);
  assert.deepEqual(['STABLE', 'FLUCTUATING', 'SUPPORT_REQUESTED', 'UNKNOWN'].map(state =>
    ui.companionVisualId(state)), [
    'fa_companion_stable', 'fa_companion_fluctuating', 'fa_companion_support_requested', 'status_ready'
  ]);
});

test('flash copy separates local save, pending, ACK and both failures', () => {
  assert.equal(flashUiLabel('LOCAL', true), '已保存在手表');
  assert.equal(flashUiLabel('PENDING', true), '已保存在手表 · 等待同步');
  assert.equal(flashUiLabel('SYNCED', true), '同步已确认');
  assert.equal(flashUiLabel('SAVE_FAILED', true), '保存失败');
  assert.equal(flashUiLabel('SYNC_FAILED', true), '已保存在手表 · 同步失败');
});

test('watch note stays pending after transport attempts and only leaves the queue on matching ACK', () => {
  const note = { flashId: 'watch_1', content: 'Remember this', sourceDevice: 'watch',
    createdAt: 100, syncStatus: 'pending' };
  const queue = new WearFlashQueue();
  queue.enqueue(note);
  const restored = new WearFlashQueue(queue.pending());
  assert.equal(restored.pending().length, 1);
  restored.ack('other');
  assert.equal(restored.pending().length, 1);
  restored.ack(note.flashId);
  assert.equal(restored.pending().length, 0);
});

test('sync failure can recover to pending but neither state is called synced without ACK', () => {
  const note = { flashId: 'watch_2', content: 'Thought', sourceDevice: 'watch', createdAt: 100,
    syncStatus: 'pending' };
  const queue = new WearFlashQueue([note]);
  assert.equal(flashTransportState(false), 'SYNC_FAILED');
  assert.equal(queue.pending().length, 1);
  assert.equal(flashTransportState(true), 'PENDING');
  assert.equal(queue.pending().length, 1);
  assert.equal(flashUiLabel('PENDING', true), '已保存在手表 · 等待同步');
  queue.ack(note.flashId);
  assert.equal(flashUiLabel('SYNCED', true), '同步已确认');
});
