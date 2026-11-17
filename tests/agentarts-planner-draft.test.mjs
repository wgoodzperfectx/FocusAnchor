import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseAgentArtsPlannerDraft } from '../scripts/agentarts-planner-draft.mjs';

const ids = { sourceEventId: 'synthetic-event-001', correlationId: 'synthetic-corr-001' };
// Final text observed in the second AgentArts Trial Run on 2026-11-16.
const evidence = JSON.parse(readFileSync(new URL('../docs/agentarts/evidence/platform-trial-2026-11-16.json', import.meta.url), 'utf8'));
const observed = evidence.trials[1].finalText;

test('validates the observed platform trial final text as a draft only', () => {
  const result = parseAgentArtsPlannerDraft(observed, ids);
  assert.equal(result.resultType, 'STEP');
  assert.equal(result.steps.length, 5);
  assert.equal(result.sourceEventId, ids.sourceEventId);
  assert.equal(result.correlationId, ids.correlationId);
  assert.equal(result.schemaVersion, undefined);
});

test('rejects the first trial object interpolation, which was not JSON', () => {
  assert.throws(() => parseAgentArtsPlannerDraft("{'resultType':'STEP'}", ids),
    { code: 'AGENTARTS_DRAFT_INVALID_JSON' });
});

test('rejects forged IDs, extra fields, empty steps and execution claims', () => {
  for (const mutation of [
    { sourceEventId: 'other' }, { delivered: true }, { steps: [] },
    { resultType: 'DONE' }, { errorCode: 'ALREADY_EXECUTED' }
  ]) {
    assert.throws(() => parseAgentArtsPlannerDraft(JSON.stringify({ ...JSON.parse(observed), ...mutation }), ids),
      { code: 'AGENTARTS_DRAFT_INVALID_SCHEMA' });
  }
});

test('CLARIFY and ERROR cannot masquerade as a step plan', () => {
  const base = { ...JSON.parse(observed), steps: [], title: '', userGoal: '' };
  assert.equal(parseAgentArtsPlannerDraft(JSON.stringify({ ...base, resultType: 'CLARIFY', question: '你想汇报什么主题？' }), ids).resultType, 'CLARIFY');
  assert.equal(parseAgentArtsPlannerDraft(JSON.stringify({ ...base, resultType: 'ERROR', errorCode: 'OUT_OF_SCOPE' }), ids).resultType, 'ERROR');
  assert.throws(() => parseAgentArtsPlannerDraft(JSON.stringify({ ...base, resultType: 'ERROR', errorCode: 'OUT_OF_SCOPE', steps: ['继续'] }), ids),
    { code: 'AGENTARTS_DRAFT_INVALID_SCHEMA' });
});
