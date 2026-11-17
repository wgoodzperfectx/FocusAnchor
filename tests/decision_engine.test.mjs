import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateDecision } from '../entry/src/main/ets/modeling/DecisionEngine.ts';

const candidate = {
  schema_version: '0.1-replay', source: 'replay', timestamp_ms: 100000,
  action: 'ask', receptivity_score: 0.9, uncertainty: 0.2,
  ood: false, executable: false,
};
const context = {
  now_ms: 100000, allow_proactive_prompt: true, do_not_disturb: false,
  user_requested_help: false, explicit_consent_this_time: false,
  time_since_last_intervention_sec: 3600, recent_rejections: 0,
  activity: 'stationary', signal_quality: 'good',
};

test('G0 passes only a valid ASK candidate; never executes it', () => {
  const result = evaluateDecision(candidate, context, true);
  assert.equal(result.outcome, 'ALLOW_ASK');
  assert.equal(result.gate_passed, true);
  assert.equal(result.executed, false);
});

test('proactive consent false blocks even a high-scoring candidate', () => {
  const result = evaluateDecision(candidate, { ...context, allow_proactive_prompt: false }, true);
  assert.equal(result.outcome, 'MANUAL_ONLY');
  assert.deepEqual(result.reason_codes, ['PROACTIVE_CONSENT_DISABLED']);
  assert.equal(result.gate_passed, false);
  const requested = evaluateDecision(candidate,
    { ...context, allow_proactive_prompt: false, user_requested_help: true }, true);
  assert.equal(requested.gate_passed, false);
});

test('suggest needs current explicit consent or user request', () => {
  const suggestion = { ...candidate, action: 'suggest' };
  assert.deepEqual(evaluateDecision(suggestion, context, true).reason_codes, ['CURRENT_CONSENT_REQUIRED']);
  assert.equal(evaluateDecision(suggestion, { ...context, explicit_consent_this_time: true }, true).outcome,
    'ALLOW_SUGGEST');
  assert.equal(evaluateDecision(suggestion, { ...context, user_requested_help: true }, true).outcome,
    'ALLOW_SUGGEST');
});

test('each hard exclusion independently denies', () => {
  const cases = [
    [{ do_not_disturb: true }, 'DO_NOT_DISTURB'],
    [{ activity: 'exercise' }, 'ACTIVITY_EXCLUSION'],
    [{ activity: 'unknown' }, 'ACTIVITY_EXCLUSION'],
    [{ signal_quality: 'invalid' }, 'BAD_SIGNAL'],
    [{ recent_rejections: 1 }, 'RECENT_REJECTION'],
    [{ time_since_last_intervention_sec: 300 }, 'COOLDOWN'],
    [{ time_since_last_intervention_sec: null }, 'COOLDOWN'],
  ];
  for (const [change, reason] of cases) {
    const result = evaluateDecision(candidate, { ...context, ...change }, true);
    assert.equal(result.gate_passed, false, reason);
    assert.deepEqual(result.reason_codes, [reason]);
  }
});

test('OOD, uncertainty, stale data, bad schema and bad score deny', () => {
  assert.deepEqual(evaluateDecision(candidate, { ...context, now_ms: 300001 }, true).reason_codes,
    ['STALE_CANDIDATE']);
  const cases = [
    [{ ood: true }, 'OOD_OR_UNCERTAIN'],
    [{ uncertainty: null }, 'OOD_OR_UNCERTAIN'],
    [{ uncertainty: 0.8 }, 'OOD_OR_UNCERTAIN'],
    [{ timestamp_ms: -1 }, 'STALE_CANDIDATE'],
    [{ schema_version: '2.1.0' }, 'INCOMPATIBLE_CANDIDATE'],
    [{ receptivity_score: NaN }, 'INVALID_SCORE'],
    [{ executable: true }, 'INVALID_CANDIDATE'],
    [{ executable: undefined }, 'INVALID_CANDIDATE'],
    [{ ood: undefined }, 'OOD_OR_UNCERTAIN'],
  ];
  for (const [change, reason] of cases) {
    const result = evaluateDecision({ ...candidate, ...change }, context, true);
    assert.equal(result.gate_passed, false, reason);
    assert.deepEqual(result.reason_codes, [reason]);
  }
});

test('service failure and no-action candidate safely stop', () => {
  assert.equal(evaluateDecision(null, context, false).outcome, 'MANUAL_ONLY');
  assert.equal(evaluateDecision({ ...candidate, action: 'abstain' }, context, true).outcome, 'MANUAL_ONLY');
  assert.equal(evaluateDecision({ ...candidate, action: 'defer' }, context, true).outcome, 'NO_ACTION');
});
