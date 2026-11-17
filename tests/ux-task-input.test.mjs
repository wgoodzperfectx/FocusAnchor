import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = readFileSync(new URL('../entry/src/main/ets/pages/AppTabs.ets', import.meta.url), 'utf8');
const dateStart = source.indexOf('  private parseDeadline(');
const dateEnd = source.indexOf('  private openNew(', dateStart);
const saveStart = source.indexOf('  private async saveTask():');
const saveEnd = source.indexOf('  /** Xiaoyi voice', saveStart);
assert.ok(dateStart > 0 && dateEnd > dateStart && saveStart > dateEnd && saveEnd > saveStart);
const Task = vm.runInNewContext(stripTypeScriptTypes(`class Task { ${source.slice(dateStart, dateEnd)} ${source.slice(saveStart, saveEnd)} }; Task;`), {
  promptAction: { showToast: () => { throw new Error('unexpected success toast'); } }
});

test('deadline accepts a real calendar time and rejects normalized or partial dates', () => {
  const page = new Task();
  assert.equal(page.parseDeadline('2026-10-29 14:30'), new Date(2026, 9, 29, 14, 30).getTime());
  for (const invalid of ['2026-02-30 14:30', '2026-13-01 08:00', '2026-10-29 25:00', '20261029 junk']) {
    assert.equal(page.parseDeadline(invalid), undefined, invalid);
  }
});

test('editing a task removed elsewhere does not report a successful save', async () => {
  const page = new Task();
  page.lang = 1;
  page.draftTitle = '报告';
  page.draftDeadline = '';
  page.editingId = 'missing';
  page.showEditor = true;
  page.appState = { tasks: [] };
  await page.saveTask();
  assert.equal(page.taskError, '任务未能保存，请重试。');
  assert.equal(page.showEditor, true);
});

test('empty task title explains why saving did not start', async () => {
  const page = new Task();
  page.lang = 1;
  page.draftTitle = '  ';
  await page.saveTask();
  assert.equal(page.taskError, '请先填写任务名称。');
});

test('failed deletion keeps the selected task and shows a retryable error', async () => {
  const page = new Task();
  page.lang = 1;
  page.selectedId = 'task';
  page.showEditor = true;
  page.appState = { clearTask: async () => { throw new Error('disk unavailable'); } };
  await page.clearSelected();
  assert.equal(page.selectedId, 'task');
  assert.equal(page.showEditor, true);
  assert.equal(page.taskError, '任务未能删除，请重试。');
});

test('saved task is not described as a failed save when list refresh fails', async () => {
  const page = new Task();
  page.lang = 1;
  page.draftTitle = '报告';
  page.draftContent = '';
  page.draftDeadline = '';
  page.draftMinutes = '25';
  page.draftMethod = 'reading';
  page.draftPriority = 2;
  page.draftInsight = '';
  page.editingId = 'task';
  page.showEditor = true;
  page.appState = {
    tasks: [{ id: 'task', title: '旧任务', content: '', completed: false, createdAt: 1 }],
    updateTask: async () => {},
    refreshDeadlinePriorities: async () => {}
  };
  page.refreshFromLocal = async () => { throw new Error('refresh failed'); };
  await page.saveTask();
  assert.equal(page.taskError, '任务已保存，但列表暂未刷新。请重新进入任务页。');
  assert.equal(page.showEditor, false);
});

test('deleted task is not described as a failed deletion when list refresh fails', async () => {
  const page = new Task();
  page.lang = 1;
  page.selectedId = 'task';
  page.showEditor = true;
  page.appState = { clearTask: async () => {} };
  page.refreshFromLocal = async () => { throw new Error('refresh failed'); };
  await page.clearSelected();
  assert.equal(page.selectedId, '');
  assert.equal(page.showEditor, false);
  assert.equal(page.taskError, '任务已删除，但列表暂未刷新。请重新进入任务页。');
});
