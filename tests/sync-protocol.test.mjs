import test from 'node:test';
import assert from 'node:assert/strict';
import { WearSyncQueue, shouldAdoptPhoneProjection } from '../wear/src/main/ets/services/WearSyncQueue.ts';
import { pendingActionEvents, retainedActionAcks } from '../entry/src/main/ets/services/SyncProtocol.ts';
import { cardEventForTap } from '../entry/src/main/ets/services/CardEventProtocol.ts';

const event = { eventId: 'watch-a1-r2-complete', taskId: 't1', actionId: 'a1', baseRevision: 2,
  type: 'complete', origin: 'watch', createdAt: 100 };

test('retries keep the same event until ack, then remove it', () => {
  const queue = new WearSyncQueue();
  queue.enqueue(event);
  queue.enqueue(event);
  assert.deepEqual(queue.pending(), [event]);
  const restored = new WearSyncQueue(queue.pending());
  assert.deepEqual(restored.pending(), [event]);
  restored.ack(event.eventId);
  assert.deepEqual(restored.pending(), []);
});

test('unrelated ack cannot drop a pending action', () => {
  const queue = new WearSyncQueue([event]);
  queue.ack('old-event');
  assert.deepEqual(queue.pending(), [event]);
});

test('phone processes only valid unacknowledged watch events', () => {
  const second = { ...event, eventId: 'watch-a1-r3-change', baseRevision: 3, type: 'change' };
  assert.deepEqual(pendingActionEvents([event, second, { eventId: 'broken' }],
    [{ eventId: event.eventId, status: 'applied', currentRevision: 3 }]), [second]);
});

test('watch never adopts a legacy whole-task write as an Action projection', () => {
  assert.equal(shouldAdoptPhoneProjection({ updatedAt: 9999, source: 'watch' }, 1), false);
  assert.equal(shouldAdoptPhoneProjection({ updatedAt: 5, source: 'phone' }, 9999), true);
});

test('stale card data cannot submit an unversioned Action operation', () => {
  assert.equal(cardEventForTap('t1', '', 0, 'start', 100), undefined);
  assert.equal(cardEventForTap('t1', 'a1', Number.NaN, 'complete', 100), undefined);
});

test('repeated card tap at one revision keeps one event identity', () => {
  const first = cardEventForTap('t1', 'a1', 2, 'complete', 100);
  const retry = cardEventForTap('t1', 'a1', 2, 'complete', 200);
  assert.equal(first?.eventId, 'card_t1_a1_2_complete');
  assert.equal(retry?.eventId, first?.eventId);
});

test('ack list retains more than one hundred current watch events without reprocessing', () => {
  const events = Array.from({ length: 120 }, (_, i) => ({ ...event, eventId: `watch-${i}` }));
  const acks = events.map((item) => ({ eventId: item.eventId, status: 'applied' }));
  assert.equal(retainedActionAcks(events, acks).length, 120);
  assert.deepEqual(pendingActionEvents(events, retainedActionAcks(events, acks)), []);
  assert.deepEqual(retainedActionAcks(events.slice(119), acks), [acks[119]]);
});

test('two pause and resume rounds use distinct IDs but pending retries reuse one ID', () => {
  const queue = new WearSyncQueue();
  const pause1 = queue.enqueueOperation('t1', 'a1', 2, 'pause', 1, 100);
  const retry = queue.enqueueOperation('t1', 'a1', 2, 'pause', pause1.nextSequence, 101);
  assert.equal(retry.event.eventId, pause1.event.eventId);
  queue.ack(pause1.event.eventId);
  const resume1 = queue.enqueueOperation('t1', 'a1', 2, 'resume', retry.nextSequence, 200);
  queue.ack(resume1.event.eventId);
  const pause2 = queue.enqueueOperation('t1', 'a1', 2, 'pause', resume1.nextSequence, 300);
  assert.notEqual(pause2.event.eventId, pause1.event.eventId);
  assert.equal(pause2.nextSequence, 4);
});
