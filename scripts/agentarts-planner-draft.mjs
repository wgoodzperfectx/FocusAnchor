/** Validates the draft text observed in AgentArts Trial Run. This is not TaskPlan 2.1.0. */
export class AgentArtsPlannerDraftError extends Error {
  constructor(code) { super(code); this.code = code; }
}

const expectedKeys = ['correlationId', 'errorCode', 'question', 'resultType',
  'sourceEventId', 'steps', 'title', 'userGoal'];
const nonempty = (value, max) => typeof value === 'string' &&
  value.trim().length > 0 && value.length <= max;

/** Parse only a model's final text after a successful platform trial or API terminal event. */
export function parseAgentArtsPlannerDraft(text, { sourceEventId, correlationId }) {
  if (typeof text !== 'string' || text.length === 0 || text.length > 16384 ||
      !nonempty(sourceEventId, 128) || !nonempty(correlationId, 128)) {
    throw new AgentArtsPlannerDraftError('AGENTARTS_DRAFT_INVALID_INPUT');
  }
  let draft;
  try { draft = JSON.parse(text); }
  catch { throw new AgentArtsPlannerDraftError('AGENTARTS_DRAFT_INVALID_JSON'); }
  if (draft === null || typeof draft !== 'object' || Array.isArray(draft) ||
      Object.keys(draft).sort().join('|') !== expectedKeys.join('|') ||
      draft.sourceEventId !== sourceEventId || draft.correlationId !== correlationId ||
      !['STEP', 'CLARIFY', 'ERROR'].includes(draft.resultType) ||
      typeof draft.title !== 'string' || typeof draft.userGoal !== 'string' ||
      typeof draft.question !== 'string' || typeof draft.errorCode !== 'string' ||
      !Array.isArray(draft.steps) || draft.steps.length > 5 ||
      !draft.steps.every(step => nonempty(step, 500))) {
    throw new AgentArtsPlannerDraftError('AGENTARTS_DRAFT_INVALID_SCHEMA');
  }
  if (draft.resultType === 'STEP' &&
      (!nonempty(draft.title, 120) || !nonempty(draft.userGoal, 500) ||
       draft.steps.length === 0 || draft.question !== '' || draft.errorCode !== '') ||
      draft.resultType === 'CLARIFY' &&
      (draft.steps.length !== 0 || !nonempty(draft.question, 500) ||
       draft.title !== '' || draft.userGoal !== '' || draft.errorCode !== '') ||
      draft.resultType === 'ERROR' &&
      (draft.steps.length !== 0 || draft.question !== '' || draft.title !== '' ||
       draft.userGoal !== '' || !['INVALID_INPUT', 'OUT_OF_SCOPE', 'SAFETY_HANDOFF_REQUIRED'].includes(draft.errorCode))) {
    throw new AgentArtsPlannerDraftError('AGENTARTS_DRAFT_INVALID_SCHEMA');
  }
  return draft;
}
