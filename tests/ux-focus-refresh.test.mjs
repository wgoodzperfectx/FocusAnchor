import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = readFileSync(new URL('../entry/src/main/ets/pages/FocusPage.ets', import.meta.url), 'utf8');
const start = source.indexOf('  private async refreshWorkspace():');
const end = source.indexOf('  private async convertFlash(', start);
assert.ok(start > 0 && end > start);
const Focus = vm.runInNewContext(stripTypeScriptTypes(`class Focus { ${source.slice(start, end)} }; Focus;`), {
  selectUnambiguousTask: (tasks) => tasks.length === 1 ? tasks[0] : undefined,
  FocusSessionService: { load: async () => null }
});

test('Focus successful refresh clears an old read error and restores the sandbox', async () => {
  const page = new Focus();
  page.lang = 1;
  page.actionError = 'old read error';
  page.appState = {
    tasks: [{ id: 'task', title: '报告' }],
    flashNotes: [{ flashId: 'note', content: '想法', archived: false }],
    reloadTasksFromDisk: async () => {},
    getPendingTasks() { return this.tasks; }
  };
  page.getUIContext = () => ({ getRouter: () => ({ getParams: () => ({}) }) });
  await page.refreshWorkspace();
  assert.equal(page.actionError, '');
  assert.equal(page.task.id, 'task');
  assert.equal(page.flashNotes.length, 1);
});
