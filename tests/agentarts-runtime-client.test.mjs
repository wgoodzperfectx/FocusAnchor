import test from 'node:test';
import assert from 'node:assert/strict';
import { invokeAgentArtsWorkflow } from '../scripts/agentarts-runtime-client.mjs';

const event = value => `data: ${JSON.stringify(value)}\n\n`;
const success = event({ event: 'workflow_finished', data: {
  status: { code: 1, desc: 'succeeded' }, execution_id: 'exec-1',
  outputs: { result: 'synthetic' }
} }) + event({ event: 'end' });
const input = { baseUrl: 'https://agentarts.example.test', runtimeName: 'FA_TaskPlanner_v0_1',
  authorization: 'Bearer synthetic-secret', requestId: 'req-1', sessionId: 'session-1',
  inputs: { task: '整理一份合成材料' } };

test('backend adapter sends one bounded invocation and returns only terminal outputs', async () => {
  let calls = 0;
  const fetchImpl = async (url, options) => {
    calls++;
    assert.equal(url, 'https://agentarts.example.test/runtimes/FA_TaskPlanner_v0_1/invocations');
    assert.equal(options.method, 'POST');
    assert.equal(options.headers.Authorization, input.authorization);
    assert.equal(options.headers['X-Request-Id'], input.requestId);
    assert.equal(options.headers['x-hw-agentarts-session-id'], input.sessionId);
    assert.deepEqual(JSON.parse(options.body), { inputs: input.inputs });
    return { ok: true, status: 200, text: async () => success };
  };
  const result = await invokeAgentArtsWorkflow({ ...input, fetchImpl });
  assert.equal(calls, 1);
  assert.deepEqual(result.outputs, { result: 'synthetic' });
  assert.equal(result.executionId, 'exec-1');
  assert.equal(result.requestId, 'req-1');
  assert.equal(result.sessionId, 'session-1');
  assert.equal(JSON.stringify(result).includes('synthetic-secret'), false);
});

test('invalid endpoint or runtime rejects before network access', async () => {
  let calls = 0;
  const fetchImpl = async () => { calls++; throw Error('unexpected'); };
  await assert.rejects(invokeAgentArtsWorkflow({ ...input, baseUrl: 'http://agentarts.example.test', fetchImpl }), { code: 'AGENTARTS_INVALID_CONFIG' });
  await assert.rejects(invokeAgentArtsWorkflow({ ...input, runtimeName: '../other', fetchImpl }), { code: 'AGENTARTS_INVALID_CONFIG' });
  assert.equal(calls, 0);
});

test('HTTP failure, malformed SSE and timeout fail without exposing credentials', async () => {
  for (const fetchImpl of [
    async () => ({ ok: false, status: 503, text: async () => 'secret in server body' }),
    async () => ({ ok: true, status: 200, text: async () => event({ event: 'end' }) }),
    async () => { throw Error('Bearer synthetic-secret'); }
  ]) {
    await assert.rejects(invokeAgentArtsWorkflow({ ...input, fetchImpl }), error => {
      assert.equal(String(error).includes('synthetic-secret'), false);
      assert.equal(String(error).includes('secret in server body'), false);
      return true;
    });
  }
  await assert.rejects(invokeAgentArtsWorkflow({ ...input, timeoutMs: 5,
    fetchImpl: async () => new Promise(() => {}) }), { code: 'AGENTARTS_TIMEOUT' });
});

test('streamed response is size bounded before SSE parsing', async () => {
  const bytes = new TextEncoder().encode(success);
  const fetchImpl = async () => ({ ok: true, body: new ReadableStream({
    start(controller) { controller.enqueue(bytes.slice(0, 17)); controller.enqueue(bytes.slice(17)); controller.close(); }
  }) });
  assert.equal((await invokeAgentArtsWorkflow({ ...input, fetchImpl })).executionId, 'exec-1');
  const oversized = async () => ({ ok: true, body: new ReadableStream({
    start(controller) { controller.enqueue(new Uint8Array(1024 * 1024 + 1)); controller.close(); }
  }) });
  await assert.rejects(invokeAgentArtsWorkflow({ ...input, fetchImpl: oversized }), { code: 'AGENTARTS_RESPONSE_TOO_LARGE' });
});
