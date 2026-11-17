import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseAgentArtsPlannerDraft } from '../scripts/agentarts-planner-draft.mjs';
import { mapAgentArtsStepDraftToTaskPlan } from '../entry/src/main/ets/services/AgentArtsPlannerMapping.ts';
import { validateTaskPlan } from '../entry/src/main/ets/services/WorkflowV21Validation.ts';
import { event, harness, NOW } from './workflow-v2.1-fixtures.mjs';

const evidence = JSON.parse(readFileSync(new URL('../docs/agentarts/evidence/platform-trial-2026-11-16.json', import.meta.url), 'utf8'));
const ids = { sourceEventId: evidence.input.sourceEventId, correlationId: evidence.input.correlationId };
const draft = parseAgentArtsPlannerDraft(evidence.trials[1].finalText, ids);
const local = {
  planId: 'plan_synthetic-event-001', planRevision: 1,
  stepIds: ['s0', 's1', 's2', 's3', 's4'], estimatedStartMinutes: [2, 2, 2, 2, 2],
  ...ids, providerId: 'agentarts-preview-fixture', providerVersion: 'draft-2026-11-16'
};

test('observed platform STEP draft maps into existing TaskPlan when App supplies identity', () => {
  const plan = mapAgentArtsStepDraftToTaskPlan(draft, local);
  assert.equal(validateTaskPlan(plan), true);
  assert.equal(plan.firstStepId, 's0');
  assert.equal(plan.plannerProvider, 'agentarts-preview-fixture');
  assert.equal(plan.steps[0].text, draft.steps[0]);
  assert.equal(plan.taskId, undefined);
});

test('model cannot change local IDs, provider provenance or claim execution', () => {
  for (const changed of [
    { ...draft, sourceEventId: 'forged' },
    { ...draft, correlationId: 'forged' },
    { ...draft, delivered: true },
    { ...draft, resultType: 'CLARIFY', steps: [] }
  ]) {
    assert.throws(() => mapAgentArtsStepDraftToTaskPlan(changed, local), /AGENTARTS_DRAFT_INVALID_SCHEMA/);
  }
  assert.throws(() => mapAgentArtsStepDraftToTaskPlan(draft, { ...local, stepIds: ['s0'] }),
    /AGENTARTS_DRAFT_INVALID_SCHEMA/);
  assert.throws(() => mapAgentArtsStepDraftToTaskPlan(draft, { ...local, stepIds: ['s0', 's0', 's2', 's3', 's4'] }),
    /AGENTARTS_DRAFT_INVALID_PLAN/);
});

test('USER_REQUEST replays the observed AgentArts draft through local G0 and confirmation', async () => {
  const h = harness();
  let calls = 0;
  h.deps.planner = {
    info: { id: 'agentarts-preview-replay', kind: 'mock', version: 'draft-fixture',
      capability: 'available', prerequisites: [] },
    async plan({ event: requested }) {
      calls++;
      return mapAgentArtsStepDraftToTaskPlan(draft, {
        ...local, planId: `plan_${requested.eventId}`,
        stepIds: draft.steps.map((_, index) => `plan_${requested.eventId}_${index}`)
      });
    }
  };
  const request = event('create_task', {
    eventId: ids.sourceEventId, correlationId: ids.correlationId,
    payload: { title: evidence.input.userGoal, text: evidence.input.userGoal }
  });
  const proposed = await h.workflow.dispatch(request);
  assert.equal(proposed.status, 'AWAITING_CONFIRMATION');
  assert.equal(calls, 1);
  assert.equal(h.policy.calls, 0);
  assert.equal((await h.store.read()).tasks.length, 0);
  const rejected = await h.workflow.confirm({ eventId: 'reject-preview-fixture',
    planId: proposed.plan.planId, planRevision: proposed.plan.planRevision,
    actor: 'user', choice: 'reject', timestamp: new Date(NOW).toISOString() });
  assert.equal(rejected.status, 'DECLINED');
  assert.equal((await h.store.read()).tasks.length, 0);
  assert.equal(h.device.calls, 0);
});

test('G0, ABSTAIN, DEFER and ASK do not call the replayed execution Provider', async () => {
  for (const decision of ['ABSTAIN', 'DEFER', 'ASK']) {
    const h = harness();
    let calls = 0;
    h.deps.planner = { info: { id: 'agentarts-preview-replay', kind: 'mock', version: 'draft-fixture',
      capability: 'available', prerequisites: [] }, async plan() { calls++; throw Error('unexpected'); } };
    h.policy.decision = decision;
    const result = await h.workflow.dispatch(event('time_due'));
    assert.equal(result.status, decision === 'DEFER' ? 'DEFERRED' :
      decision === 'ASK' ? 'AWAITING_CLARIFICATION' : 'ABSTAINED');
    assert.equal(calls, 0);
  }
  const h = harness();
  let calls = 0;
  h.deps.planner = { info: { id: 'agentarts-preview-replay', kind: 'mock', version: 'draft-fixture',
    capability: 'available', prerequisites: [] }, async plan() { calls++; throw Error('unexpected'); } };
  h.auth.granted = false;
  assert.equal((await h.workflow.dispatch(event())).status, 'BLOCKED');
  assert.equal(calls, 0);
});

test('invalid replayed model text fails safely without Task or Action persistence', async () => {
  const h = harness();
  h.deps.planner = { info: { id: 'agentarts-preview-replay', kind: 'mock', version: 'draft-fixture',
    capability: 'available', prerequisites: [] },
  async plan() { return parseAgentArtsPlannerDraft("{'resultType':'STEP'}", ids); } };
  const result = await h.workflow.dispatch(event());
  assert.equal(result.status, 'FAILED_SAFE');
  assert.equal((await h.store.read()).tasks.length, 0);
  assert.equal(h.device.calls, 0);
});

test('accepted replayed STEP is persisted only by the local App workflow', async () => {
  const h = harness();
  h.deps.planner = { info: { id: 'agentarts-preview-replay', kind: 'mock', version: 'draft-fixture',
    capability: 'available', prerequisites: [] },
  async plan() { return mapAgentArtsStepDraftToTaskPlan(draft, local); } };
  const request = event('create_task', {
    eventId: ids.sourceEventId, correlationId: ids.correlationId,
    payload: { title: evidence.input.userGoal, text: evidence.input.userGoal }
  });
  const proposed = await h.workflow.dispatch(request);
  assert.equal(proposed.status, 'AWAITING_CONFIRMATION');
  assert.equal((await h.store.read()).tasks.length, 0);
  const accepted = await h.workflow.confirm({ eventId: 'accept-preview-fixture',
    planId: proposed.plan.planId, planRevision: proposed.plan.planRevision,
    actor: 'user', choice: 'accept', timestamp: new Date(NOW).toISOString() });
  assert.equal(accepted.status, 'DELIVERED');
  assert.equal(accepted.card.action, draft.steps[0]);
  assert.equal((await h.store.read()).tasks.length, 1);
});
