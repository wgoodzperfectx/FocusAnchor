import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const index = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
const focus = readFileSync(new URL('../entry/src/main/ets/pages/FocusPage.ets', import.meta.url), 'utf8');

test('Focus tab embeds the sandbox directly and keeps the tab selected on return', () => {
  assert.match(index, /TabContent\(\)\s*\{\s*FocusContent\(\{ embedded: true/);
  assert.doesNotMatch(index, /openFocus\(|if \(this\.currentIndex === 2\) this\.currentIndex = 0/);
});

test('standalone Focus route retains a visible back action', () => {
  assert.match(focus, /@Entry\s*@Component\s*struct FocusPage/);
  assert.match(focus, /FocusContent\(\{ onClose: \(\) => this\.getUIContext\(\)\.getRouter\(\)\.back\(\) \}\)/);
});
