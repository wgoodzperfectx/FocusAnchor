import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = readFileSync(new URL('../entry/src/main/ets/pages/UiReadModels.ts', import.meta.url), 'utf8');
const start = source.indexOf('export function flashSyncState(');
const end = source.indexOf('export interface UiCurrentAction', start);
assert.ok(start > 0 && end > start);
const flashSyncState = vm.runInNewContext(stripTypeScriptTypes(`${source.slice(start, end).replace('export ', '')}; flashSyncState;`));

for (const [input, expected] of [
  ['local', 'LOCAL'], ['pending', 'PENDING'], ['synced', 'SYNCED'],
  ['failed', 'FAILED'], ['unrecognized', 'UNKNOWN']
]) {
  test(`Flash note receipt ${input} is shown as ${expected}`, () => {
    assert.equal(flashSyncState(input), expected);
  });
}
