import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { invokeAgentArtsPlannerDraft } from '../scripts/agentarts-planner-provider.mjs';
import { mapAgentArtsStepDraftToTaskPlan } from '../entry/src/main/ets/services/AgentArtsPlannerMapping.ts';
import { event, harness, NOW } from './workflow-v2.1-fixtures.mjs';

const evidence = JSON.parse(readFileSync(new URL(
  '../docs/agentarts/evidence/platform-trial-2026-11-16.json', import.meta.url), 'utf8'));
const trialText = evidence.trials[1].finalText;
const request = event('create_task', {
  eventId: evidence.input.sourceEventId,
  correlationId: evidence.input.correlationId,
  payload: { title: evidence.input.userGoal, text: evidence.input.userGoal }
});
const sse = result => `data: ${JSON.stringify({ event: 'workflow_finished', data: {
  status: { code: 1, desc: 'succeeded' }, execution_id: 'offline-execution',
  outputs: { result }
} })}\n\ndata: ${JSON.stringify({ event: 'end' })}\n\n`;

function bindOfflinePlanner(h, finalText = trialText) {
  let calls = 0;
  h.deps.planner = {
    info: { id: 'agentarts-offline-integration', kind: 'mock', version: '2.1.0-test',
      capability: 'available', prerequisites: [] },
    async plan({ event: requested, existing, previous, edit }) {
      const approvedQuery = JSON.stringify({
        schemaVersion: '2.1.0', channel: requested.channel === 'USER' ?
          'USER_REQUEST' : 'AUTHORIZED_CONTEXT_EVENT',
        sourceEventId: requested.eventId, correlationId: requested.correlationId,
        userGoal: requested.payload.text ?? requested.payload.title ?? existing?.content,
        ...(existing ? { existingStepSummary: existing.focusStep.text } : {}),
        ...(edit ? { edit } : {})
      });
      const response = await invokeAgentArtsPlannerDraft({
        baseUrl: 'https://agentarts.example.test', runtimeName: 'offline-only',
        authorization: 'Bearer synthetic-secret', requestId: 'offline-request',
        sessionId: 'offline-session', approvedQuery,
        sourceEventId: requested.eventId, correlationId: requested.correlationId,
        fetchImpl: async (_, options) => {
          calls++;
          assert.deepEqual(JSON.parse(options.body), { inputs: { query: approvedQuery } });
          return { ok: true, text: async () => sse(finalText) };
        }
      });
      const { draft } = response;
      const planId = previous?.planId ?? `plan_${requested.eventId}`;
      return mapAgentArtsStepDraftToTaskPlan(draft, {
        planId, planRevision: (previous?.planRevision ?? 0) + 1,
        taskId: existing?.id ?? requested.payload.taskId,
        stepIds: draft.steps.map((_, index) => `${planId}_${index}`),
        estimatedStartMinutes: draft.steps.map(() => 2),
        sourceEventId: requested.eventId, correlationId: requested.correlationId,
        providerId: 'agentarts-offline-integration', providerVersion: '2.1.0-test'
      });
    }
  };
  return { get calls() { return calls; } };
}

test('offline AgentArts-shaped STEP passes G0, draft validation and local confirmation', async () => {
  const h = harness(); const transport = bindOfflinePlanner(h);
  const proposal = await h.workflow.dispatch(request);
  assert.equal(proposal.status, 'AWAITING_CONFIRMATION');
  assert.equal(transport.calls, 1);
  assert.equal(h.policy.calls, 0);
  assert.equal((await h.store.read()).tasks.length, 0);
  assert.equal(h.device.calls, 0);
  const accepted = await h.workflow.confirm({
    eventId: 'offline-accept', actor: 'user', choice: 'accept',
    planId: proposal.plan.planId, planRevision: proposal.plan.planRevision,
    timestamp: new Date(NOW).toISOString()
  });
  assert.equal(accepted.status, 'DELIVERED');
  assert.equal(accepted.card.action, proposal.plan.steps[0].text);
  assert.equal(transport.calls, 1);
  assert.equal((await h.store.read()).tasks.length, 1);
});

test('G0 rejection and local M2 ABSTAIN/DEFER/ASK never reach offline transport', async () => {
  const blocked = harness(); const blockedTransport = bindOfflinePlanner(blocked);
  blocked.auth.granted = false;
  assert.equal((await blocked.workflow.dispatch(request)).status, 'BLOCKED');
  assert.equal(blockedTransport.calls, 0);
  for (const [decision, status] of [
    ['ABSTAIN', 'ABSTAINED'], ['DEFER', 'DEFERRED'],
    ['ASK', 'AWAITING_CLARIFICATION']
  ]) {
    const h = harness(); const transport = bindOfflinePlanner(h);
    h.policy.decision = decision;
    assert.equal((await h.workflow.dispatch(event('time_due'))).status, status);
    assert.equal(transport.calls, 0);
  }
});

test('invalid offline Runtime result fails safe before local persistence or sync', async () => {
  const h = harness(); const transport = bindOfflinePlanner(h, "{'resultType':'STEP'}");
  const result = await h.workflow.dispatch(request);
  assert.equal(result.status, 'FAILED_SAFE');
  assert.equal(transport.calls, 1);
  assert.equal((await h.store.read()).tasks.length, 0);
  assert.equal(h.device.calls, 0);
});
