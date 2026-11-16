/** Backend-only AgentArts invocation boundary. Never bundle this module into HarmonyOS. */
import { performance } from 'node:perf_hooks';
import { parseAgentArtsWorkflowSse } from '../entry/src/main/ets/services/AgentArtsSse.ts';

export class AgentArtsInvocationError extends Error {
  constructor(code) { super(code); this.code = code; }
}

const validId = value => typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/.test(value);
const plainRecord = value => value !== null && typeof value === 'object' &&
  !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype;
const MAX_RESPONSE_BYTES = 1024 * 1024;

async function readBoundedText(response) {
  if (response.body && typeof response.body.getReader === 'function') {
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let length = 0;
    let text = '';
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        if (!(value instanceof Uint8Array)) throw new AgentArtsInvocationError('AGENTARTS_INVALID_RESPONSE');
        length += value.byteLength;
        if (length > MAX_RESPONSE_BYTES) throw new AgentArtsInvocationError('AGENTARTS_RESPONSE_TOO_LARGE');
        text += decoder.decode(value, { stream: true });
      }
      return text + decoder.decode();
    } finally {
      await reader.cancel().catch(() => {});
    }
  }
  if (typeof response.text !== 'function') throw new AgentArtsInvocationError('AGENTARTS_INVALID_RESPONSE');
  const text = await response.text();
  if (typeof text !== 'string' || Buffer.byteLength(text, 'utf8') > MAX_RESPONSE_BYTES) {
    throw new AgentArtsInvocationError('AGENTARTS_RESPONSE_TOO_LARGE');
  }
  return text;
}

function endpoint(baseUrl, runtimeName) {
  let url;
  try { url = new URL(baseUrl); }
  catch { throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash ||
      url.pathname !== '/' || !validId(runtimeName)) {
    throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG');
  }
  url.pathname = `/runtimes/${encodeURIComponent(runtimeName)}/invocations`;
  return url.toString();
}

/** Caller supplies actual Runtime Name, HTTPS origin, credential and approved inputs. */
export async function invokeAgentArtsWorkflow({ baseUrl, runtimeName, authorization,
  requestId, sessionId, inputs, fetchImpl = globalThis.fetch, timeoutMs = 15000 }) {
  const url = endpoint(baseUrl, runtimeName);
  if (!validId(requestId) || !validId(sessionId) || !plainRecord(inputs) ||
      typeof authorization !== 'string' || !authorization.trim() ||
      typeof fetchImpl !== 'function' || !Number.isInteger(timeoutMs) ||
      timeoutMs < 1 || timeoutMs > 60000) {
    throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG');
  }
  let body;
  try { body = JSON.stringify({ inputs }); }
  catch { throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG'); }
  if (body.length > 32768) throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG');

  const started = performance.now();
  const controller = new AbortController();
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      reject(new AgentArtsInvocationError('AGENTARTS_TIMEOUT'));
    }, timeoutMs);
  });
  try {
    const operation = (async () => {
      const response = await fetchImpl(url, {
        method: 'POST',
        headers: {
          Authorization: authorization,
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'X-Request-Id': requestId,
          'x-hw-agentarts-session-id': sessionId
        },
        body,
        signal: controller.signal
      });
      if (!response?.ok) throw new AgentArtsInvocationError('AGENTARTS_HTTP_ERROR');
      const final = parseAgentArtsWorkflowSse(await readBoundedText(response));
      return { ...final, requestId, sessionId, durationMs: Math.round(performance.now() - started) };
    })();
    return await Promise.race([operation, deadline]);
  } catch (error) {
    if (error instanceof AgentArtsInvocationError || error?.code?.startsWith('AGENTARTS_')) throw error;
    throw new AgentArtsInvocationError('AGENTARTS_NETWORK_ERROR');
  } finally {
    clearTimeout(timer);
  }
}
