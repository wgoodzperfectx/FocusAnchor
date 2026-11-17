import test from 'node:test';
import assert from 'node:assert/strict';
import { parseAgentArtsWorkflowSse } from '../entry/src/main/ets/services/AgentArtsSse.ts';

const line = value => `data: ${JSON.stringify(value)}\n\n`;
const finish = (outputs = { user_fields: { result: 'STEP' } }, status = { code: 1, desc: 'succeeded' }) =>
  ({ event: 'workflow_finished', data: { status, outputs, execution_id: 'exec-synthetic-1' }, createdTime: 1790000000000 });

test('uses only successful workflow_finished output, never a message fragment', () => {
  const stream = line({ event: 'workflow_started', data: { start_time: 1 } }) +
    line({ event: 'message', data: { text: '{"forged":"plan"}' } }) +
    line(finish({ user_fields: { status: 'STEP', plan: { planId: 'p1' } } })) +
    line({ event: 'end', createdTime: 1790000000001 });
  assert.deepEqual(parseAgentArtsWorkflowSse(stream), {
    executionId: 'exec-synthetic-1',
    outputs: { user_fields: { status: 'STEP', plan: { planId: 'p1' } } }
  });
});

test('rejects error event even if later terminal event claims success', () => {
  const stream = line({ event: 'error', data: { error_code: 'AgentArts.500' } }) +
    line(finish()) + line({ event: 'end' });
  assert.throws(() => parseAgentArtsWorkflowSse(stream), { code: 'AGENTARTS_REMOTE_ERROR' });
});

test('rejects waiting workflow instead of treating a question as a completed plan', () => {
  const stream = line({ event: 'node_wait', data: { node_id: 'question' } }) +
    line(finish({}, { code: 1, desc: 'waiting' })) + line({ event: 'end' });
  assert.throws(() => parseAgentArtsWorkflowSse(stream), { code: 'AGENTARTS_NOT_COMPLETED' });
});

test('rejects truncated, malformed and ambiguous streams', () => {
  const fragments = [
    line({ event: 'message', data: { text: 'partial' } }),
    line(finish()),
    'data: {invalid json}\n\n',
    line(finish()) + line(finish()) + line({ event: 'end' })
  ];
  for (const stream of fragments) assert.throws(() => parseAgentArtsWorkflowSse(stream));
});

test('does not accept failed terminal status or missing outputs', () => {
  assert.throws(() => parseAgentArtsWorkflowSse(line(finish({}, { code: 2, desc: 'failed' })) + line({ event: 'end' })), { code: 'AGENTARTS_NOT_COMPLETED' });
  assert.throws(() => parseAgentArtsWorkflowSse(line(finish(null)) + line({ event: 'end' })), { code: 'AGENTARTS_INVALID_OUTPUT' });
});
