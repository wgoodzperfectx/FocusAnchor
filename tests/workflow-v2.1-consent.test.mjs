import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const root = new URL('../entry/src/main/ets/', import.meta.url);

// Execute the production ArkTS classes, replacing only platform I/O imports.
function loadModule(path, bindings = {}) {
  let source = readFileSync(new URL(path, root), 'utf8');
  source = source.replace(/^import[\s\S]*?;\r?\n/gm, '').replace(/export default /g, '').replace(/export /g, '');
  if (path === 'pages/SettingsPage.ets') {
    source = source.slice(0, source.indexOf('  build() {')) + '\n}';
    source = source.replace(/^@(?:Entry|Component)\r?\n/gm, '')
      .replace(/@State /g, '').replace('struct SettingsPage', 'class SettingsPage');
  }
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

function storageHarness(values = new Map()) {
  const defaults = loadModule('models/AppTypes.ets');
  const { StorageService } = loadModule('services/StorageService.ets', {
    ...defaults,
    preferences: { async getPreferences() { return {
      async get(key, fallback) { return values.get(key) ?? fallback; },
      async put(key, value) { values.set(key, value); },
      async flush() {}
    }; } }
  });
  return { storage: StorageService.getInstance(), values };
}

test('settings merge preserves explicit opt-in across a storage restart', async () => {
  const { DEFAULT_SETTINGS } = loadModule('models/AppTypes.ets');
  const { storage, values } = storageHarness();
  await storage.init({});
  await storage.saveSettings({ ...DEFAULT_SETTINGS, privacy: {
    ...DEFAULT_SETTINGS.privacy, consentFocusSupport: true, consentThoughtSandbox: true
  } });
  const restarted = storageHarness(values).storage;
  await restarted.init({});
  const loaded = await restarted.loadSettings();
  assert.equal(loaded.privacy.consentFocusSupport, true);
  assert.equal(loaded.privacy.consentThoughtSandbox, true);
  const { routeFocusAnchor } = routing();
  assert.equal(routeFocusAnchor('新闪念', loaded.privacy).thoughtStored, true);
});

for (const [name, privacy] of [
  ['missing privacy', undefined], ['missing switches', {}],
  ['revocation', { consentFocusSupport: false, consentThoughtSandbox: false }],
  ['string switches', { consentFocusSupport: 'true', consentThoughtSandbox: 'true' }],
  ['numeric switches', { consentFocusSupport: 1, consentThoughtSandbox: 1 }],
  ['null switches', { consentFocusSupport: null, consentThoughtSandbox: null }]
]) {
  test(`settings merge ${name} leaves both switches explicitly off`, async () => {
    const values = new Map([['settings_plain', JSON.stringify({ privacy })]]);
    const { storage } = storageHarness(values);
    await storage.init({});
    const loaded = await storage.loadSettings();
    assert.equal(loaded.privacy.consentFocusSupport, false);
    assert.equal(loaded.privacy.consentThoughtSandbox, false);
  });
}

function settingsPage(settings) {
  const { DEFAULT_PRIVACY } = loadModule('models/AppTypes.ets');
  const state = { settings,
    async updateSettings(value) { state.settings = value; } };
  const { SettingsPage } = loadModule('pages/SettingsPage.ets', {
    DEFAULT_PRIVACY, AppState: { getInstance() { return state; } },
    t(key) { return key; }, promptAction: { showToast() {} }
  });
  return { page: new SettingsPage(), state };
}

test('saving unrelated settings retains the explicit focus and sandbox choices', async () => {
  const { DEFAULT_SETTINGS } = loadModule('models/AppTypes.ets');
  const { page, state } = settingsPage({ ...DEFAULT_SETTINGS, privacy: {
    ...DEFAULT_SETTINGS.privacy, consentFocusSupport: true, consentThoughtSandbox: true
  } });
  page.loadFromState();
  assert.equal(page.consentFocusSupport, true);
  assert.equal(page.consentThoughtSandbox, true);
  page.userName = 'Changed profile';
  await page.saveAll();
  assert.equal(state.settings.privacy.consentFocusSupport, true);
  assert.equal(state.settings.privacy.consentThoughtSandbox, true);
});

test('settings page defaults never opt in and can persist explicit revocation', async () => {
  const { DEFAULT_SETTINGS } = loadModule('models/AppTypes.ets');
  const { page, state } = settingsPage({ ...DEFAULT_SETTINGS, privacy: {} });
  page.loadFromState();
  assert.equal(page.consentFocusSupport, false);
  assert.equal(page.consentThoughtSandbox, false);
  page.consentFocusSupport = true;
  page.consentThoughtSandbox = true;
  await page.saveAll();
  assert.equal(state.settings.privacy.consentFocusSupport, true);
  assert.equal(state.settings.privacy.consentThoughtSandbox, true);
  page.consentFocusSupport = false;
  page.consentThoughtSandbox = false;
  await page.saveAll();
  assert.equal(state.settings.privacy.consentFocusSupport, false);
  assert.equal(state.settings.privacy.consentThoughtSandbox, false);
});

function pageMethod(path, name, bindings) {
  const source = readFileSync(new URL(path, root), 'utf8');
  const begin = source.indexOf(`  private ${name}(`);
  const asyncBegin = source.indexOf(`  private async ${name}(`);
  const start = begin >= 0 ? begin : asyncBegin;
  assert.ok(start >= 0);
  const end = source.indexOf('\n  private ', start + 1);
  assert.ok(end > start);
  const js = stripTypeScriptTypes(`class Page { ${source.slice(start, end)} }\n;Page;`, { mode: 'strip' });
  return vm.runInNewContext(js, bindings);
}

test('Step Session local rule cannot turn a missing consent switch into opt-in', () => {
  const { proposeFirstStep } = routing();
  const Page = pageMethod('pages/StepSessionPage.ets', 'proposeLocalRule', { proposeFirstStep });
  const page = new Page();
  page.appState = { settings: { privacy: {} } };
  page.lang = 1;
  page.task = task;
  page.tr = (zh) => zh;
  page.proposeLocalRule();
  assert.notEqual(page.state, 'FALLBACK');
});

test('guide breakdown cannot turn a missing consent switch into opt-in', async () => {
  const { proposeFirstStep } = routing();
  const Page = pageMethod('pages/GuidePage.ets', 'breakDown', { proposeFirstStep });
  const page = new Page();
  page.taskTitle = task.title;
  page.taskId = task.id;
  page.appState = { settings: { privacy: {} }, tasks: [task] };
  page.tr = (zh) => zh;
  page.stepText = '';
  page.changeStatus = async () => {};
  page.scheduleConfirmation = () => {};
  await page.breakDown();
  assert.equal(page.stepText, '');
});
