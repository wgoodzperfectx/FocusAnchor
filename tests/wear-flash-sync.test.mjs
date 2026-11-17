import test from 'node:test';
import assert from 'node:assert/strict';
import { WearFlashQueue, flashIdForSequence } from '../wear/src/main/ets/services/WearFlashNoteService.ts';
import { pendingFlashNotes, retainedFlashAcks } from '../entry/src/main/ets/services/SyncProtocol.ts';

const note = { flashId: 'watch-device-1', content: 'Review chapter', sourceDevice: 'watch',
  createdAt: 100, syncStatus: 'pending' };

test('watch keeps a FlashNote pending through restart until phone ack', () => {
  const queue = new WearFlashQueue();
  queue.enqueue(note);
  queue.enqueue(note);
  const restored = new WearFlashQueue(queue.pending());
  assert.deepEqual(restored.pending(), [note]);
  restored.ack(note.flashId);
  assert.deepEqual(restored.pending(), []);
});

test('phone filters acknowledged and malformed FlashNotes', () => {
  const other = { ...note, flashId: 'watch-device-2', content: 'Call advisor' };
  assert.deepEqual(pendingFlashNotes([note, other, { flashId: 'bad', content: '' }],
    ['watch-device-1']), [other]);
});

test('flash acknowledgements keep only IDs still in the watch queue', () => {
  assert.deepEqual(retainedFlashAcks([note], ['old', note.flashId, note.flashId]), [note.flashId]);
});

test('local sequence gives separate notes stable distinct IDs', () => {
  assert.equal(flashIdForSequence('device-a', 1), 'watch_device-a_1');
  assert.equal(flashIdForSequence('device-a', 2), 'watch_device-a_2');
});

test('malformed cached note does not discard valid pending notes', () => {
  const queue = new WearFlashQueue([{ flashId: 'bad' }, note]);
  assert.deepEqual(queue.pending(), [note]);
});
