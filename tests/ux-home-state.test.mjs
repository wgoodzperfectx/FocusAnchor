import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = readFileSync(new URL('../entry/src/main/ets/pages/AppTabs.ets', import.meta.url), 'utf8');
const start = source.indexOf('  private currentTask():');
const end = source.indexOf('  private openStep(', start);
assert.ok(start > 0 && end > start);
const Home = vm.runInNewContext(stripTypeScriptTypes(`class Home { ${source.slice(start, end)} }; Home;`), {
  selectUnambiguousTask: (tasks) => tasks.length === 1 ? tasks[0] : undefined
});

function scene(step, taskCount = 1, pausedActionId = '', dataError = '') {
  const home = new Home();
  home.lang = 1;
  home.pausedActionId = pausedActionId;
  home.appState = {
    dataError,
    tasks: taskCount === 1 ? [{ id: 'task', title: '报告', focusStep: step }] :
      Array.from({ length: taskCount }, (_, i) => ({ id: `task${i}`, title: `任务${i}` })),
    getPendingTasks() { return this.tasks; }
  };
  return [home.homeMessage(), home.homeAction(), home.companionState()];
}

test('Home empty state leads to task creation', () => {
  assert.deepEqual(scene(undefined, 0), ['先记下一件想做的事。', '记下一件事', 'IDLE']);
});
test('Home task without Action leads to Step Session', () => {
  assert.deepEqual(scene(undefined), ['要不要从第一小步开始？', '拆成第一步', 'IDLE']);
});
test('Home ready Action offers start', () => {
  assert.deepEqual(scene({ actionId: 'a', status: 'ready' }), ['这一步已经准备好了。', '开始这一步', 'STEP']);
});
test('Home active Action offers continuation', () => {
  assert.deepEqual(scene({ actionId: 'a', status: 'in_progress' }), ['我们接着做这一小步。', '继续这一步', 'ACTIVE']);
});
test('Home paused session takes precedence over active Action', () => {
  assert.deepEqual(scene({ actionId: 'a', status: 'in_progress' }, 1, 'a'), ['随时可以回来。', '继续这一步', 'PAUSED']);
});
test('Home completed Action leads back to task choice', () => {
  assert.deepEqual(scene({ actionId: 'a', status: 'completed' }), ['这一步完成了。', '查看下一步', 'COMPLETE']);
});
test('Home ambiguous tasks ask for an explicit choice', () => {
  assert.deepEqual(scene(undefined, 2), ['从任务里选一件，作为眼前的主线。', '查看任务', 'IDLE']);
});
test('Home data failure does not present a stale Action as current', () => {
  assert.deepEqual(scene({ actionId: 'a', status: 'in_progress' }, 1, '', 'read failed'),
    ['我暂时没有获取到最新状态。', '查看任务', 'IDLE']);
});
