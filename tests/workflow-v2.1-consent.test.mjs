import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const root = new URL('../entry/src/main/ets/', import.meta.url);

// Execute the production ArkTS classes, replacing only platform I/O imports.
function loadModule(path, bindings = {}) {
  let source = readFileSync(new URL(path, root), 'utf8');
  source = source.replace(/^import .*;\r?\n/gm, '').replace(/export default /g, '').replace(/export /g, '');
  const names = [...source.matchAll(/^(?:async )?function (\w+)|^class (\w+)|^const (DEFAULT_\w+)/gm)]
    .map((match) => match[1] ?? match[2] ?? match[3]);
  const context = vm.createContext({ ...bindings });
  const js = stripTypeScriptTypes(source, { mode: 'strip' });
  return vm.runInContext(`${js}\n;({ ${names.join(',')} });`, context);
}

function consentBindings() {
  const helper = new URL('services/FocusConsent.ts', root);
  return existsSync(helper) ? loadModule('services/FocusConsent.ts') : {};
}

function routing() {
  const { FocusAnchorSession } = loadModule('focusanchoragentextability/FocusAnchorSession.ets');
  const routes = loadModule('focusanchoragentextability/FocusAnchorRouter.ets', {
    FocusAnchorSession, ...consentBindings()
  });
  return { ...routes, session: FocusAnchorSession.getInstance() };
}

const task = { id: 'private-task', title: '保密论文', content: '写下一句', completed: false };

// A missing-consent permissive branch would expose task data or retain thoughts.
for (const [name, runtime] of [
  ['no runtime', undefined],
  ['missing focus switch', { consentThoughtSandbox: true, activeTask: task }],
  ['revoked focus switch', { consentFocusSupport: false, consentThoughtSandbox: true, activeTask: task }],
  ['nonboolean focus switch', { consentFocusSupport: 'true', consentThoughtSandbox: true, activeTask: task }]
]) {
  test(`${name} denies personal-task access and thought capture`, () => {
    const { routeFocusAnchor, session } = routing();
    for (const text of ['我要买牛奶', '找回刚才', '陪我学习']) {
      const decision = routeFocusAnchor(text, runtime);
      assert.equal(decision.intent, 'consent');
      assert.equal(decision.thoughtStored, false);
      assert.equal(decision.userVisibleText.includes('保密论文'), false);
    }
    assert.equal(session.thoughts.length, 0);
  });
}

test('denial happens before reading activeTask', () => {
  const { routeFocusAnchor } = routing();
  const runtime = { consentFocusSupport: false, consentThoughtSandbox: true,
    get activeTask() { throw new Error('personal task read before consent'); } };
  assert.equal(routeFocusAnchor('找回刚才', runtime).intent, 'consent');
});

test('first-step generation requires explicit consent before reading the task', () => {
  const { proposeFirstStep } = routing();
  const privateTask = { get title() { throw new Error('private task read'); } };
  for (const consent of [undefined, false, 'true', 1]) {
    assert.equal(proposeFirstStep(privateTask, consent), undefined);
  }
  assert.equal(proposeFirstStep(task, true), '写下一句');
});

for (const value of [undefined, false, 'true', 1]) {
  test(`sandbox value ${String(value)} cannot retain a thought`, () => {
    const { routeFocusAnchor, session } = routing();
    const result = routeFocusAnchor('我要买牛奶', {
      consentFocusSupport: true, consentThoughtSandbox: value, activeTask: task
    });
    assert.equal(result.thoughtStored, false);
    assert.equal(session.thoughts.length, 0);
  });
}

test('explicit opt-in preserves task support and respects do-not-save', () => {
  const { routeFocusAnchor, session } = routing();
  const runtime = { consentFocusSupport: true, consentThoughtSandbox: true, activeTask: task };
  assert.match(routeFocusAnchor('找回刚才', runtime).userVisibleText, /保密论文/);
  assert.equal(routeFocusAnchor('我要买牛奶', runtime).thoughtStored, true);
  assert.equal(session.thoughts[0].text, '我要买牛奶');
  assert.equal(routeFocusAnchor('不要保存这个念头', runtime).thoughtStored, false);
  assert.equal(session.thoughts.length, 1);
});

test('pause and safety remain available without consent', () => {
  const { routeFocusAnchor, session } = routing();
  assert.equal(routeFocusAnchor('暂停').companionPaused, true);
  assert.equal(routeFocusAnchor('想死').intent, 'safety');
  assert.equal(routeFocusAnchor('停药').intent, 'safety');
  assert.equal(session.thoughts.length, 0);
});

function runtimeHarness(raw, failPreferences = false) {
  const effects = [];
  const runtime = loadModule('focusanchoragentextability/FocusAnchorRuntime.ets', {
    preferences: { async getPreferences() {
      effects.push('privacy');
      if (failPreferences) throw new Error('settings unavailable');
      return { async get() { return raw; } };
    } },
    FocusAnchorStore: { async hydrate() { effects.push('hydrate'); } },
    TaskFileService: { getInstance() {
      effects.push('task-service');
      return { init() { effects.push('init'); }, async loadTasks() { effects.push('tasks'); return [task]; } };
    } },
    ...consentBindings()
  });
  return { ...runtime, effects };
}

for (const [name, raw, broken] of [
  ['missing settings', '', false],
  ['missing privacy', '{}', false],
  ['legacy privacy', '{"privacy":{"localEncryptionOnly":true}}', false],
  ['revocation', '{"privacy":{"consentFocusSupport":false,"consentThoughtSandbox":true}}', false],
  ['malformed JSON', '{', false],
  ['null payload', 'null', false],
  ['failed settings load', '', true]
]) {
  test(`${name} never reads tasks or hydrates personal session`, async () => {
    const { loadFocusRuntime, effects } = runtimeHarness(raw, broken);
    const runtime = await loadFocusRuntime({});
    assert.equal(runtime.consentFocusSupport, false);
    assert.equal(runtime.consentThoughtSandbox, false);
    assert.equal(runtime.activeTask, undefined);
    assert.deepEqual(effects, ['privacy']);
  });
}

test('authorized runtime reads privacy before personal session and task files', async () => {
  const { loadFocusRuntime, effects } = runtimeHarness('{"privacy":{"consentFocusSupport":true,"consentThoughtSandbox":true}}');
  const runtime = await loadFocusRuntime({});
  assert.equal(runtime.activeTask.title, '保密论文');
  assert.equal(runtime.consentThoughtSandbox, true);
  assert.deepEqual(effects, ['privacy', 'hydrate', 'task-service', 'init', 'tasks']);
});

test('new-install defaults deny task and thought access at their consumer', () => {
  const { DEFAULT_PRIVACY } = loadModule('models/AppTypes.ets');
  const { routeFocusAnchor, session } = routing();
  assert.equal(routeFocusAnchor('找回刚才', { ...DEFAULT_PRIVACY, activeTask: task }).intent, 'consent');
  assert.equal(routeFocusAnchor('新的闪念', DEFAULT_PRIVACY).thoughtStored, false);
  assert.equal(session.thoughts.length, 0);
});

async function abilityHarness(runtime, rejected = false) {
  const { routeFocusAnchor, session } = routing();
  const effects = [];
  const { FocusAnchorAgentExtAbility } = loadModule('focusanchoragentextability/FocusAnchorAgentExtAbility.ets', {
    AgentExtensionAbility: class {}, hilog: { info() {} }, routeFocusAnchor,
    async loadFocusRuntime() { if (rejected) throw new Error('load failed'); return runtime; },
    FocusAnchorStore: { hydrate() { effects.push('hydrate'); return Promise.resolve(); },
      async persist() { effects.push('persist'); } },
    ...consentBindings()
  });
  const ability = new FocusAnchorAgentExtAbility();
  ability.context = {};
  ability.onCreate({});
  const response = await new Promise((resolve) => ability.onData({ sendData: resolve }, '我要买牛奶'));
  return { response, session, effects };
}

for (const [name, runtime, rejected] of [
  ['load rejection', undefined, true],
  ['revoked consent', { consentFocusSupport: false, consentThoughtSandbox: false }, false],
  ['missing sandbox switch', { consentFocusSupport: true }, false]
]) {
  test(`ability ${name} does not hydrate on create or persist thoughts`, async () => {
    const { response, session, effects } = await abilityHarness(runtime, rejected);
    assert.equal(session.thoughts.length, 0);
    assert.equal(effects.includes('persist'), false);
    assert.equal(effects.includes('hydrate'), false);
    assert.equal(response.includes('本地，不上传'), false);
  });
}
