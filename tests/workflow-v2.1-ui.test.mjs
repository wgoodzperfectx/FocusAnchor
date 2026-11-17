import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

function session(appState) {
  const source = readFileSync(new URL('../entry/src/main/ets/pages/StepSessionPage.ets', import.meta.url), 'utf8');
  const start = source.indexOf('  private showPlan(');
  const end = source.indexOf('  private async setStatus(', start);
  assert.ok(start > 0 && end > start, 'Step Session must own the V2.1 interaction');
  const Page = vm.runInNewContext(stripTypeScriptTypes(`class Page { ${source.slice(start, end)} }; Page;`), {
    proposeFirstStep: () => undefined
  });
  const page = new Page();
  Object.assign(page, {
    appState, lang: 1, busy: false, state: 'IDLE', planId: '', planRevision: 0,
    draftStep: '', originalStep: '', task: { id: 'task', title: '报告', content: '写报告' },
    tr: (cn) => cn, getUIContext: () => ({ getRouter: () => ({ back() { page.didBack = true; } }) })
  });
  return page;
}

const plan = {
  planId: 'plan', planRevision: 1, firstStepId: 's1', plannerProvider: 'local-mock',
  steps: [{ stepId: 's1', order: 0, text: '打开文档' }, { stepId: 's2', order: 1, text: '写提纲' }]
};

test('Step Session shows the local proposal and updates an edited first step before confirmation', async () => {
  const calls = [];
  const page = session({
    async proposeWorkflowV21() { return { status: 'AWAITING_CONFIRMATION', plan }; },
    async confirmWorkflowV21(...args) {
      calls.push(args);
      return { status: 'AWAITING_CONFIRMATION', plan: {
        ...plan, planRevision: 2,
        steps: [{ ...plan.steps[0], text: args[3] }, plan.steps[1]]
      } };
    }
  });
  await page.propose();
  assert.equal(page.state, 'STEP');
  assert.equal(page.draftStep, '打开文档');
  assert.equal(page.plannerLabel, 'local-mock');
  page.draftStep = '打开参考文献';
  await page.updatePlan();
  assert.equal(calls[0][2], 'modify');
  assert.equal(page.planRevision, 2);
  assert.equal(page.originalStep, '打开参考文献');
});

test('Step Session rejection closes the pending draft without saving a task', async () => {
  const calls = [];
  const page = session({
    async proposeWorkflowV21() { return { status: 'AWAITING_CONFIRMATION', plan }; },
    async confirmWorkflowV21(...args) { calls.push(args); return { status: 'DECLINED' }; }
  });
  await page.propose();
  await page.rejectPlan();
  assert.equal(calls[0][2], 'reject');
  assert.equal(page.planId, '');
  assert.equal(page.didBack, true);
});
