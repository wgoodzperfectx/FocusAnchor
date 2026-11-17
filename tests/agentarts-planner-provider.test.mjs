import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { invokeAgentArtsPlannerDraft } from '../scripts/agentarts-planner-provider.mjs';

const evidence = JSON.parse(readFileSync(new URL(
  '../docs/agentarts/evidence/platform-trial-2026-11-16.json', import.meta.url), 'utf8'));
const approvedQuery = JSON.stringify(evidence.input);
const request = {
  baseUrl: 'https://agentarts.example.test', runtimeName: 'FA_TaskPlanner_v0_1',
  authorization: 'Bearer synthetic-secret', requestId: 'req-1', sessionId: 'session-1',
  approvedQuery, sourceEventId: evidence.input.sourceEventId,
  correlationId: evidence.input.correlationId
};
const sse = result => `data: ${JSON.stringify({ event: 'workflow_finished', data: {
  status: { code: 1, desc: 'succeeded' }, execution_id: 'synthetic-exec',
  outputs: { result }
} })}\n\ndata: ${JSON.stringify({ event: 'end' })}\n\n`;

test('candidate binding consumes observed STEP text through fake Runtime SSE', async () => {
  let calls = 0;
  const fetchImpl = async (_, options) => {
    calls++;
    assert.deepEqual(JSON.parse(options.body), { inputs: { query: approvedQuery } });
    return { ok: true, text: async () => sse(evidence.trials[1].finalText) };
  };
  const result = await invokeAgentArtsPlannerDraft({ ...request, fetchImpl });
  assert.equal(calls, 1);
  assert.equal(result.draft.resultType, 'STEP');
  assert.equal(result.draft.sourceEventId, evidence.input.sourceEventId);
  assert.equal(result.executionId, 'synthetic-exec');
  assert.equal(JSON.stringify(result).includes('synthetic-secret'), false);
});

test('authorized context label uses the same single planner input shape offline', async () => {
  let calls = 0;
  const query = JSON.stringify({ ...evidence.input,
    channel: 'AUTHORIZED_CONTEXT_EVENT', existingStepSummary: '恢复已确认的提纲第一步' });
  const fetchImpl = async (_, options) => {
    calls++;
    assert.deepEqual(JSON.parse(options.body), { inputs: { query } });
    return { ok: true, text: async () => sse(evidence.trials[1].finalText) };
  };
  const result = await invokeAgentArtsPlannerDraft({ ...request,
    approvedQuery: query, fetchImpl });
  assert.equal(calls, 1);
  assert.equal(result.draft.resultType, 'STEP');
});

test('missing End result, forged correlation and malformed model text fail closed', async () => {
  for (const [output, code] of [
    [null, 'AGENTARTS_INVALID_OUTPUT'],
    [JSON.stringify({ ...JSON.parse(evidence.trials[1].finalText),
      correlationId: 'forged' }), 'AGENTARTS_DRAFT_INVALID_SCHEMA'],
    ["{'resultType':'STEP'}", 'AGENTARTS_DRAFT_INVALID_JSON']
  ]) {
    const fetchImpl = async () => ({ ok: true, text: async () => sse(output) });
    await assert.rejects(invokeAgentArtsPlannerDraft({ ...request, fetchImpl }), { code });
  }
});

test('bad local request is rejected before any network attempt', async () => {
  let calls = 0;
  const fetchImpl = async () => { calls++; throw Error('unexpected'); };
  await assert.rejects(invokeAgentArtsPlannerDraft({ ...request,
    approvedQuery: '', fetchImpl }), { code: 'AGENTARTS_INVALID_CONFIG' });
  await assert.rejects(invokeAgentArtsPlannerDraft({ ...request,
    approvedQuery: JSON.stringify({ ...evidence.input, correlationId: 'forged' }),
    fetchImpl }), { code: 'AGENTARTS_INVALID_CONFIG' });
  await assert.rejects(invokeAgentArtsPlannerDraft({ ...request,
    approvedQuery: JSON.stringify({ ...evidence.input, channel: 'CONTEXT_TRIGGER' }),
    fetchImpl }), { code: 'AGENTARTS_INVALID_CONFIG' });
  await assert.rejects(invokeAgentArtsPlannerDraft({ ...request,
    approvedQuery: JSON.stringify({ ...evidence.input, rawHeartRate: [92, 96] }),
    fetchImpl }), { code: 'AGENTARTS_INVALID_CONFIG' });
  await assert.rejects(invokeAgentArtsPlannerDraft({ ...request,
    approvedQuery: JSON.stringify({ ...evidence.input, preciseLocation: 'synthetic' }),
    fetchImpl }), { code: 'AGENTARTS_INVALID_CONFIG' });
  assert.equal(calls, 0);
});
