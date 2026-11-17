import test from 'node:test';
import assert from 'node:assert/strict';
import { validateEvent, validateContextFeatures, validateInterventionDecision, validateTaskPlan } from '../entry/src/main/ets/services/WorkflowV21Validation.ts';
import { event, harness } from './workflow-v2.1-fixtures.mjs';

test('contract: rejects unknown version, forged channel, invalid timestamp and prohibited payload', () => {
  assert.equal(validateEvent(event()), true);
  for (const change of [{ schemaVersion: '3.0.0' }, { channel: 'CONTEXT' }, { occurredAt: 'tomorrow' },
    { payload: { title: 'task', raw_sensor_stream: [1] } }, { consent: null }]) {
    assert.equal(validateEvent(event('create_task', change)), false);
  }
});
test('contract: missing physiological/location values remain missing and evidence must resolve', async () => {
  const h = harness();
  const features = await h.estimator.estimate(event('time_due'));
  assert.equal(validateContextFeatures(features), true);
  assert.equal(validateContextFeatures({ ...features, missingFields: [] }), false);
  const decision = await h.policy.decide(features);
  assert.equal(validateInterventionDecision({ ...decision, evidenceReferences: ['invented'] }, features), false);
  assert.equal(validateInterventionDecision({ ...decision, contextId: 'wrong' }, features), false);
  assert.equal(validateInterventionDecision({ ...decision, decision: 'ABSTAIN', suggestedActionType: 'resume_step' }, features), false);
});
test('contract: plans reject duplicates, invalid first step, and blank/oversized text', async () => {
  const h = harness();
  const plan = await h.planner.plan({ event: event() });
  assert.equal(validateTaskPlan(plan), true);
  assert.equal(validateTaskPlan({ ...plan, steps: [plan.steps[0], plan.steps[0]] }), false);
  assert.equal(validateTaskPlan({ ...plan, firstStepId: 'missing' }), false);
  assert.equal(validateTaskPlan({ ...plan, title: '' }), false);
  assert.equal(validateTaskPlan({ ...plan, steps: [{ ...plan.steps[0], text: 'x'.repeat(501) }] }), false);
});
