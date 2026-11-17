/** Backend-only candidate binding for the observed Start query / End result draft.
 *  The caller owns G0, user consent, request identity and credential storage.
 *  This binding remains unverified against the published Runtime API.
 */
import { invokeAgentArtsWorkflow, AgentArtsInvocationError } from './agentarts-runtime-client.mjs';
import { parseAgentArtsPlannerDraft } from './agentarts-planner-draft.mjs';

const nonempty = (value, max) => typeof value === 'string' &&
  value.trim().length > 0 && value.length <= max;
const allowedQueryKeys = new Set(['schemaVersion', 'channel', 'sourceEventId',
  'correlationId', 'userGoal', 'existingStepSummary', 'edit']);

export async function invokeAgentArtsPlannerDraft({ approvedQuery, sourceEventId,
  correlationId, ...transport }) {
  if (!nonempty(approvedQuery, 16384) || !nonempty(sourceEventId, 128) ||
      !nonempty(correlationId, 128)) {
    throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG');
  }
  let query;
  try { query = JSON.parse(approvedQuery); }
  catch { throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG'); }
  if (query === null || typeof query !== 'object' || Array.isArray(query) ||
      Object.getPrototypeOf(query) !== Object.prototype ||
      Object.keys(query).some(key => !allowedQueryKeys.has(key)) ||
      query.schemaVersion !== '2.1.0' ||
      !['USER_REQUEST', 'AUTHORIZED_CONTEXT_EVENT'].includes(query.channel) ||
      query.sourceEventId !== sourceEventId || query.correlationId !== correlationId ||
      !nonempty(query.userGoal, 500) ||
      (query.existingStepSummary !== undefined &&
        !nonempty(query.existingStepSummary, 500)) ||
      (query.edit !== undefined && !nonempty(query.edit, 500))) {
    throw new AgentArtsInvocationError('AGENTARTS_INVALID_CONFIG');
  }
  const response = await invokeAgentArtsWorkflow({
    ...transport, inputs: { query: approvedQuery }
  });
  if (typeof response.outputs.result !== 'string') {
    throw new AgentArtsInvocationError('AGENTARTS_INVALID_OUTPUT');
  }
  return {
    requestId: response.requestId,
    sessionId: response.sessionId,
    executionId: response.executionId,
    durationMs: response.durationMs,
    draft: parseAgentArtsPlannerDraft(response.outputs.result, {
      sourceEventId, correlationId
    })
  };
}
