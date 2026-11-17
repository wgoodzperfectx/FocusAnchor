import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = readFileSync(new URL('../entry/src/main/ets/pages/StepSessionPage.ets', import.meta.url), 'utf8');
const start = source.indexOf('  private message():');
const end = source.indexOf('  build()', start);
assert.ok(start > 0 && end > start);
const Session = vm.runInNewContext(stripTypeScriptTypes(`class Session { ${source.slice(start, end)} }; Session;`));
const loadStart = source.indexOf('  private async loadTask():');
const loadEnd = source.indexOf('  private showPlan(', loadStart);
assert.ok(loadStart > 0 && loadEnd > loadStart);
const LoadSession = vm.runInNewContext(stripTypeScriptTypes(`class LoadSession { ${source.slice(loadStart, loadEnd)} }; LoadSession;`), {
  FocusSessionService: { load: async () => null }
});
const planEnd = source.indexOf('  private async propose():', loadEnd);
const updateStart = source.indexOf('  private async updatePlan():');
const updateEnd = source.indexOf('  private async rejectPlan():', updateStart);
assert.ok(planEnd > loadEnd && updateStart > planEnd && updateEnd > updateStart);
const PlanSession = vm.runInNewContext(stripTypeScriptTypes(`class PlanSession { ${source.slice(loadEnd, planEnd)} ${source.slice(updateStart, updateEnd)} }; PlanSession;`));

for (const [state, text, visual] of [
  ['LOADING', '正在等待步骤建议。', 'LOADING'],
  ['STEP', '先从这一小步开始。', 'STEP'],
  ['CLARIFY', '我还想确认一件事。', 'CLARIFY'],
  ['ERROR', '暂时没有完成。', 'ERROR'],
  ['FALLBACK', '先试试这个简化建议。', 'FALLBACK'],
  ['SAVED', '这一步已经记下了。', 'SAVED']
]) {
  test(`Step Session ${state} presents its own message and companion state`, () => {
    const page = new Session();
    page.lang = 1;
    page.tr = (cn) => cn;
    page.state = state;
    page.sessionPaused = false;
    page.task = { focusStep: { status: 'ready' } };
    assert.equal(page.message(), text);
    assert.equal(page.visualState(), visual);
  });
}

test('saved paused Action uses the paused companion state', () => {
  const page = new Session();
  page.lang = 1;
  page.tr = (cn) => cn;
  page.state = 'SAVED';
  page.sessionPaused = true;
  page.task = { focusStep: { status: 'in_progress' } };
  assert.equal(page.visualState(), 'PAUSED');
});

test('opening a completed Action shows completion without proposing the same step again', async () => {
  const page = new LoadSession();
  page.lang = 1;
  page.tr = (cn) => cn;
  page.errorText = 'old error';
  page.sessionPaused = true;
  page.appState = {
    tasks: [{ id: 'task', title: '报告', focusStep: { actionId: 'action', text: '完成摘要', status: 'completed' } }],
    reloadTasksFromDisk: async () => {}
  };
  page.getUIContext = () => ({ getRouter: () => ({ getParams: () => ({ taskId: 'task' }) }), getHostContext: () => ({}) });
  await page.loadTask();
  assert.equal(page.state, 'COMPLETE');
  assert.equal(page.draftStep, '完成摘要');
  assert.equal(page.errorText, '');
  assert.equal(page.sessionPaused, false);
});

test('accepted plan modification keeps user edit provenance visible in the session', async () => {
  const page = new PlanSession();
  page.planId = 'plan';
  page.planRevision = 1;
  page.draftStep = '先列出三项要求';
  page.appState = { confirmWorkflowV21: async () => ({
    status: 'AWAITING_CONFIRMATION',
    plan: { planId: 'plan', planRevision: 2, firstStepId: 'step', plannerProvider: 'mock-task-planner',
      steps: [{ stepId: 'step', text: '先列出三项要求' }] }
  }) };
  await page.updatePlan();
  assert.equal(page.state, 'STEP');
  assert.equal(page.userEdited, true);
  assert.equal(page.originalStep, '先列出三项要求');
  assert.equal(page.planRevision, 2);
});
