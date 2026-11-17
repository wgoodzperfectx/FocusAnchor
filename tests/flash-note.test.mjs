import test from 'node:test';
import assert from 'node:assert/strict';
import { mergeFlashNotes, flashTaskId, markFlashConverted, archiveFlash } from '../entry/src/main/ets/services/FlashNoteLogic.ts';

const note = { flashId: 'watch-1', content: '想到论文目录', sourceDevice: 'watch', createdAt: 10, syncStatus: 'pending' };

test('arrival is deduplicated and cannot resurrect an archived note', () => {
  const once = mergeFlashNotes([], [note]);
  assert.equal(once.length, 1);
  assert.equal(mergeFlashNotes(once, [note]).length, 1);
  const archived = archiveFlash(once, note.flashId);
  assert.equal(mergeFlashNotes(archived, [note])[0].archived, true);
});

test('conversion keeps a deterministic task identity', () => {
  const id = flashTaskId(note.flashId);
  assert.equal(id, flashTaskId(note.flashId));
  const converted = markFlashConverted([note], note.flashId, id);
  assert.equal(markFlashConverted(converted, note.flashId, id)[0].convertedTaskId, id);
});
