import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import { WorkflowV21 } from '../entry/src/main/ets/services/WorkflowV21Router.ts';
import { createMockRuntime } from '../entry/src/main/ets/services/WorkflowV21Mocks.ts';
import { WorkflowV21SnapshotStore } from '../entry/src/main/ets/services/WorkflowV21SnapshotStore.ts';
import { normalizeFocusAction } from '../entry/src/main/ets/services/ActionLogic.ts';

const root = new URL('../entry/src/main/ets/', import.meta.url);
const clone = value => JSON.parse(JSON.stringify(value));
function loadModule(path, bindings = {}) {
  const url = new URL(path, root);
  assert.ok(existsSync(url), `${path} is required for the opt-in local bridge`);
  const source = readFileSync(url, 'utf8').replace(/^import[\s\S]*?;\r?\n/gm, '').replace(/export /g, '');
  const names = [...source.matchAll(/^class (\w+)|^(?:async )?function (\w+)/gm)].map(m => m[1] ?? m[2]);
  return vm.runInNewContext(`${stripTypeScriptTypes(source, { mode: 'strip' })}\n;({${names.join(',')}});`, {
    ...bindings, Date, Promise, Uint8Array, ArrayBuffer, Error, setTimeout, clearTimeout
  });
}

// Platform-only fake: the production snapshot and workflow code still execute.
function filesystem() {
  const files = new Map();
  const handles = new Map();
  let next = 1;
  const fs = {
    failRename: false, failWrite: false, renames: [], syncs: 0,
    OpenMode: { READ_ONLY: 0, READ_WRITE: 1, CREATE: 2, TRUNC: 4 },
    accessSync(path) { return files.has(path); },
    openSync(path, mode) {
      if (mode & 2) files.set(path, new Uint8Array());
      if (!files.has(path)) throw new Error('ENOENT');
      const file = { fd: next++ };
      handles.set(file.fd, path);
      return file;
    },
    statSync(path) { return { size: files.get(path).length }; },
    readSync(fd, buffer) { const value = files.get(handles.get(fd)); new Uint8Array(buffer).set(value); return value.length; },
    writeSync(fd, buffer) {
      if (fs.failWrite) throw new Error('disk full');
      const value = new Uint8Array(buffer); files.set(handles.get(fd), new Uint8Array(value)); return value.length;
    },
    fsyncSync() { fs.syncs++; },
    closeSync(file) { handles.delete(typeof file === 'number' ? file : file.fd); },
    renameSync(from, to) {
      if (fs.failRename) throw new Error('rename failed');
      assert.equal(from.slice(0, from.lastIndexOf('/')), to.slice(0, to.lastIndexOf('/')));
      fs.renames.push([from, to]); files.set(to, files.get(from)); files.delete(from);
    },
    unlinkSync(path) { files.delete(path); }
  };
  const util = {
    TextEncoder: class { encodeInto(text) { return new TextEncoder().encode(text); } },
    TextDecoder: class { decodeToString(bytes) { return new TextDecoder().decode(bytes); } }
  };
  return { fs, util, files, handles };
}

function harness(initial = []) {
  const io = filesystem();
  const storeTypes = loadModule('services/WorkflowV21Store.ets', { ...io, WorkflowV21SnapshotStore });
  const module = loadModule('services/WorkflowV21AppService.ets', {
    ...storeTypes, WorkflowV21, createMockRuntime, normalizeFocusAction
  });
  let disk = clone(initial);
  let writes = 0;
  let failSave = false;
  let consent = true;
  let consentVersion = 1;
  const taskFile = {
    async withExclusive(work) { return work(); },
    async loadTasks() { return clone(disk); },
    async saveTasks(tasks) { if (failSave) throw new Error('task disk failed'); writes++; disk = clone(tasks); }
  };
  const context = { filesDir: '/app/files' };
  const service = () => new module.WorkflowV21AppService(context, taskFile, () => consent, () => consentVersion);
  return { ...io, ...storeTypes, ...module, context, taskFile, service,
    disk: () => clone(disk), writes: () => writes,
    consent(value) { if (consent !== value) consentVersion++; consent = value; }, failSave(value) { failSave = value; },
    editDisk(fn) { disk = fn(clone(disk)); }
  };
}

const legacy = {
  id: 'old-task', title: '报告', content: '已有正文', completed: false, createdAt: 5,
  studyMinutes: 45, studyMethod: 'practice', priority: 1, basePriority: 1,
  dueAt: 9999999999999, insight: '已有说明', customMetadata: 'preserve',
  focusStep: { taskId: 'old-task', actionId: 'canonical-action', text: '已有第一步', status: 'in_progress',
    order: 3, updatedAt: 8, revision: 4, generationSource: 'manual', appliedEventIds: ['start-1'] }
};

test('proposal and rejection never project an unconfirmed task', async () => {
  const h = harness([legacy]);
  const bridge = h.service();
  const proposed = await bridge.propose('新报告', '整理材料');
  assert.equal(proposed.status, 'AWAITING_CONFIRMATION');
  assert.equal(h.writes(), 0);
  const rejected = await bridge.confirm(proposed.plan.planId, 1, 'reject');
  assert.equal(rejected.status, 'DECLINED');
  assert.deepEqual(h.disk(), [legacy]);
  assert.equal(h.writes(), 0);
});

test('acceptance persists one local task and never reports mock watch delivery', async () => {
  const h = harness();
  const bridge = h.service();
  const proposed = await bridge.propose('写报告', '先整理报告材料');
  const result = await bridge.confirm(proposed.plan.planId, 1, 'accept');
  assert.equal(result.status, 'LOCAL_CONFIRMED');
  assert.match(result.message, /真机/);
  assert.equal(h.disk().length, 1);
  const task = h.disk()[0];
  assert.equal(task.title, '写报告');
  assert.equal(task.content, '先整理报告材料');
  assert.equal(task.focusStep.actionId, result.card.actionId);
  assert.equal(task.focusStep.status, 'ready');
  assert.equal(task.studyMinutes, 25);
  const snapshot = JSON.parse(new TextDecoder().decode(h.files.get('/app/files/workflow_v21.json')));
  assert.equal(snapshot.receipts.some(receipt => receipt.status === 'delivered'), false);
});

test('resuming the same step retains canonical action and every legacy metadata field', async () => {
  const h = harness([legacy]);
  const bridge = h.service();
  const proposed = await bridge.propose(legacy.title, '', legacy.id);
  assert.equal(proposed.plan.taskId, legacy.id);
  const result = await bridge.confirm(proposed.plan.planId, 1, 'accept');
  assert.equal(result.status, 'LOCAL_CONFIRMED');
  assert.deepEqual(h.disk(), [legacy]);
  assert.equal(result.card.actionId, 'canonical-action');
});

test('existing task without a step receives its confirmed step without duplicating the task', async () => {
  const noStep = { ...legacy }; delete noStep.focusStep;
  const h = harness([noStep]);
  const bridge = h.service();
  const proposed = await bridge.propose(legacy.title, legacy.content, legacy.id);
  const result = await bridge.confirm(proposed.plan.planId, 1, 'accept');
  assert.equal(result.status, 'LOCAL_CONFIRMED');
  assert.equal(h.disk().length, 1);
  assert.equal(h.disk()[0].id, legacy.id);
  assert.equal(h.disk()[0].studyMinutes, 45);
});

test('revoking consent after proposal blocks confirmation and restoration', async () => {
  const h = harness([legacy]);
  const bridge = h.service();
  const proposed = await bridge.propose('新报告', '整理材料');
  h.consent(false);
  assert.equal((await bridge.confirm(proposed.plan.planId, 1, 'accept')).status, 'BLOCKED');
  assert.equal(await bridge.restoreProjection(), false);
  assert.equal(h.writes(), 0);
  assert.deepEqual(h.disk(), [legacy]);
});

test('projection recovers an accepted snapshot after task-file failure and replays idempotently', async () => {
  const h = harness();
  const bridge = h.service();
  const proposed = await bridge.propose('写报告', '整理材料');
  h.failSave(true);
  assert.equal((await bridge.confirm(proposed.plan.planId, 1, 'accept')).reason, 'TASK_PROJECTION_FAILED');
  h.failSave(false);
  const restarted = h.service();
  assert.equal(await restarted.restoreProjection(), true);
  const action = h.disk()[0].focusStep.actionId;
  assert.equal(await restarted.restoreProjection(), false);
  assert.equal((await restarted.confirm(proposed.plan.planId, 1, 'accept')).status, 'LOCAL_CONFIRMED');
  assert.equal(h.disk().length, 1);
  assert.equal(h.disk()[0].focusStep.actionId, action);
  assert.equal(h.writes(), 1);
});

test('restoration never rolls a newer canonical action backwards', async () => {
  const h = harness([legacy]);
  const bridge = h.service();
  const draft = await bridge.propose(legacy.title, '', legacy.id);
  await bridge.confirm(draft.plan.planId, 1, 'accept');
  h.editDisk(tasks => tasks.map(task => ({ ...task, title: '用户后来修改',
    focusStep: { ...task.focusStep, status: 'completed', revision: 5, updatedAt: 100 } })));
  assert.equal(await h.service().restoreProjection(), false);
  assert.equal(h.disk()[0].title, '用户后来修改');
  assert.equal(h.disk()[0].focusStep.status, 'completed');
});

test('snapshot rename failure keeps the last durable snapshot and closes files', async () => {
  const h = harness();
  const store = new h.WorkflowV21Store(h.context);
  await store.transact(data => { data.controls.paused = true; });
  h.fs.failRename = true;
  await assert.rejects(store.transact(data => { data.controls.paused = false; }), { message: 'WORKFLOW_SNAPSHOT_REPLACE_FAILED' });
  assert.equal((await new h.WorkflowV21Store(h.context).read()).controls.paused, true);
  assert.equal(h.handles.size, 0);
  assert.equal(h.fs.syncs >= 1, true);
});

function appHarness(h) {
  const effects = [];
  const noOp = { getInstance() { return {}; } };
  const { AppState } = loadModule('services/AppState.ets', {
    WorkflowV21AppService: h.WorkflowV21AppService,
    StorageService: { getInstance() { return { async saveBundle() { effects.push('bundle'); }, async saveSettings() {} }; } },
    TaskFileService: { getInstance() { return h.taskFile; } },
    FlashNoteService: noOp,
    WatchSyncService: { getInstance() { return { async pushTasksToWatch() { effects.push('watch'); },
      async pushLanguage() { effects.push('language'); } }; } },
    HeartRateService: class {}, AdviceService: class {},
    FocusCardService: { async refresh() { effects.push('card'); } },
    sortTasks: value => value, normalizeFocusAction,
    effectivePriorityNearDeadline: loadModule('models/AppTypes.ets').effectivePriorityNearDeadline,
    XiaoyiBridge: { getInstance() { return { async init() {} }; } },
    ReminderService: { getInstance() { return { startPeriodicCheck() {} }; } }
  });
  const state = AppState.getInstance();
  state.context = h.context;
  state.settings.privacy.consentFocusSupport = true;
  return { state, effects };
}

test('AppState explicit API saves local bundle without real watch or card projections', async () => {
  const h = harness();
  const { state, effects } = appHarness(h);
  const proposed = await state.proposeWorkflowV21('写报告', '整理材料');
  assert.equal(proposed.status, 'AWAITING_CONFIRMATION');
  const result = await state.confirmWorkflowV21(proposed.plan.planId, 1, 'accept');
  assert.equal(result.status, 'LOCAL_CONFIRMED');
  assert.equal(state.tasks.length, 1);
  assert.deepEqual(effects, ['bundle']);
});

test('local bundle persistence cannot delete a task concurrently added on disk', async () => {
  const h = harness();
  const { state, effects } = appHarness(h);
  const draft = await state.proposeWorkflowV21('写报告', '整理材料');
  const load = h.taskFile.loadTasks;
  let loads = 0;
  h.taskFile.loadTasks = async () => {
    if (++loads === 3) h.editDisk(tasks => [...tasks, legacy]);
    return load();
  };
  assert.equal((await state.confirmWorkflowV21(draft.plan.planId, 1, 'accept')).status, 'LOCAL_CONFIRMED');
  assert.equal(h.disk().length, 2);
  assert.equal(state.tasks.length, 2);
  assert.deepEqual(effects, ['bundle']);
});

test('text-only proposal derives a nonblank title before entering the mock planner', async () => {
  const h = harness();
  const draft = await h.service().propose('', '整理会议记录');
  assert.equal(draft.status, 'AWAITING_CONFIRMATION');
  assert.equal(draft.plan.title, '整理会议记录');
});

test('modified plan remains unprojected until the new revision is accepted', async () => {
  const h = harness();
  const bridge = h.service();
  const original = await bridge.propose('写报告', '整理材料');
  const modified = await bridge.confirm(original.plan.planId, 1, 'modify', '只打开一个材料');
  assert.equal(modified.status, 'AWAITING_CONFIRMATION');
  assert.equal(modified.plan.planRevision, 2);
  assert.equal(h.writes(), 0);
  assert.equal((await bridge.confirm(original.plan.planId, 1, 'accept')).status, 'CONFLICT');
  const accepted = await bridge.confirm(modified.plan.planId, 2, 'accept');
  assert.equal(accepted.status, 'LOCAL_CONFIRMED');
  assert.equal(h.disk()[0].focusStep.text, '只打开一个材料');
});

for (const consent of [undefined, false, 'true', 1]) {
  test(`AppState consent ${String(consent)} never instantiates or runs the workflow`, async () => {
    const h = harness([legacy]);
    const { state, effects } = appHarness(h);
    state.settings.privacy.consentFocusSupport = consent;
    assert.equal((await state.proposeWorkflowV21('新任务', '新内容')).status, 'BLOCKED');
    assert.equal((await state.confirmWorkflowV21('unknown', 1, 'accept')).status, 'BLOCKED');
    assert.equal(await state.recoverWorkflowV21(), false);
    assert.equal(state.workflowV21, undefined);
    assert.equal(h.files.size, 0);
    assert.equal(h.writes(), 0);
    assert.deepEqual(effects, []);
  });
}

test('snapshot partial write cannot replace a valid durable snapshot', async () => {
  const h = harness();
  const store = new h.WorkflowV21Store(h.context);
  await store.transact(data => { data.controls.paused = true; });
  h.fs.writeSync = () => 1;
  await assert.rejects(store.transact(data => { data.controls.paused = false; }), { message: 'WORKFLOW_SNAPSHOT_REPLACE_FAILED' });
  assert.equal((await new h.WorkflowV21Store(h.context).read()).controls.paused, true);
  assert.equal(h.handles.size, 0);
});
test('review: revoked and regranted scope cannot revive an old draft', async () => {
  const h = harness(); const service = h.service(); const draft = await service.propose('报告', '写提纲');
  h.consent(false); h.consent(true);
  assert.equal((await service.confirm(draft.plan.planId, 1, 'accept')).status, 'BLOCKED'); assert.equal(h.disk().length, 0);
});
test('review: AppState bootstrap recovers accepted task after interrupted projection', async () => {
  const h = harness(); const service = h.service(); const draft = await service.propose('报告', '写提纲');
  h.failSave(true); assert.equal((await service.confirm(draft.plan.planId, 1, 'accept')).reason, 'TASK_PROJECTION_FAILED'); h.failSave(false);
  const { state } = appHarness(h);
  state.storage.init = async () => {}; state.storage.loadLanguage = async () => 1;
  state.storage.loadBundle = async () => ({ tasks: [], heartRateHistory: [], settings: state.settings });
  state.flashFile = { init() {}, async load() { return []; } }; h.taskFile.init = () => {};
  state.watchSync.init = async () => {}; state.watchSync.startActionListening = async () => {}; state.watchSync.startFlashListening = async () => {};
  await state.bootstrap(h.context); assert.equal(h.disk().length, 1); assert.equal(state.tasks.length, 1);
});
test('review: AppState persists monotonic consent generation through revoke and regrant', async () => {
  const h = harness(); const { state } = appHarness(h); state.persist = async () => {};
  const first = await state.proposeWorkflowV21('报告', '写提纲');
  const revoked = clone(state.settings); revoked.privacy.consentFocusSupport = false; await state.updateSettings(revoked, '');
  const regranted = clone(state.settings); regranted.privacy.consentFocusSupport = true; await state.updateSettings(regranted, '');
  assert.equal(state.settings.privacy.workflowConsentVersion, 3);
  assert.equal((await state.confirmWorkflowV21(first.plan.planId, 1, 'accept')).status, 'BLOCKED');
});
