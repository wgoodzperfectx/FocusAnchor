/** Experimental G0 gate. Pure evaluation only; this module performs no action. */

export type CandidateAction = 'abstain' | 'defer' | 'ask' | 'suggest';
export type GateOutcome = 'NO_ACTION' | 'ALLOW_ASK' | 'ALLOW_SUGGEST' | 'MANUAL_ONLY';

export interface DecisionCandidate {
  schema_version: string;
  source: string;
  timestamp_ms: number;
  action: CandidateAction;
  receptivity_score: number | null;
  uncertainty: number | null;
  ood: boolean;
  executable: boolean;
}

export interface GateContext {
  now_ms: number;
  allow_proactive_prompt: boolean;
  do_not_disturb: boolean;
  user_requested_help: boolean;
  explicit_consent_this_time: boolean;
  time_since_last_intervention_sec: number | null;
  recent_rejections: number;
  activity: 'stationary' | 'walking' | 'exercise' | 'unknown';
  signal_quality: 'good' | 'degraded' | 'invalid' | 'unknown';
}

export interface GateResult {
  outcome: GateOutcome;
  reason_codes: string[];
  candidate_action: CandidateAction | 'none';
  gate_version: string;
  gate_passed: boolean;
  executed: boolean;
}

const VERSION = 'g0_replay_001';
const COOLDOWN_SEC = 15 * 60;
const MAX_AGE_MS = 2 * 60 * 1000;
const MAX_UNCERTAINTY = 0.5;

function deny(reason: string, action: CandidateAction | 'none' = 'none',
              manual: boolean = false): GateResult {
  return { outcome: manual ? 'MANUAL_ONLY' : 'NO_ACTION',
    reason_codes: [reason], candidate_action: action, gate_version: VERSION,
    gate_passed: false, executed: false };
}

/** Failure is a deterministic no-action decision; the existing manual path is external. */
export function evaluateDecision(candidate: DecisionCandidate | null,
                                 context: GateContext,
                                 serviceAvailable: boolean): GateResult {
  if (!serviceAvailable || candidate === null) {
    return deny('SERVICE_UNAVAILABLE', 'none', true);
  }
  if (candidate.schema_version !== '0.1-replay' || candidate.source !== 'replay') {
    return deny('INCOMPATIBLE_CANDIDATE', candidate.action, true);
  }
  if (candidate.executable !== false || !['abstain', 'defer', 'ask', 'suggest'].includes(candidate.action)) {
    return deny('INVALID_CANDIDATE', candidate.action, true);
  }
  if (!Number.isFinite(candidate.timestamp_ms) || !Number.isFinite(context.now_ms) ||
      candidate.timestamp_ms < 0 || context.now_ms < candidate.timestamp_ms ||
      context.now_ms - candidate.timestamp_ms > MAX_AGE_MS) {
    return deny('STALE_CANDIDATE', candidate.action, true);
  }
  if (candidate.action === 'abstain') {
    return deny('CANDIDATE_ABSTAIN', candidate.action, true);
  }
  if (candidate.action === 'defer') {
    return deny('CANDIDATE_DEFER', candidate.action);
  }
  if (!context.allow_proactive_prompt) {
    return deny('PROACTIVE_CONSENT_DISABLED', candidate.action, true);
  }
  if (context.do_not_disturb !== false) {
    return deny('DO_NOT_DISTURB', candidate.action);
  }
  if (context.activity === 'exercise' || context.activity === 'unknown') {
    return deny('ACTIVITY_EXCLUSION', candidate.action);
  }
  if (context.signal_quality !== 'good') {
    return deny('BAD_SIGNAL', candidate.action, true);
  }
  if (candidate.ood !== false || candidate.uncertainty === null ||
      !Number.isFinite(candidate.uncertainty) || candidate.uncertainty < 0 ||
      candidate.uncertainty > MAX_UNCERTAINTY) {
    return deny('OOD_OR_UNCERTAIN', candidate.action, true);
  }
  if (candidate.receptivity_score === null || !Number.isFinite(candidate.receptivity_score) ||
      candidate.receptivity_score < 0 || candidate.receptivity_score > 1) {
    return deny('INVALID_SCORE', candidate.action);
  }
  if (!Number.isInteger(context.recent_rejections) || context.recent_rejections < 0 ||
      context.recent_rejections > 0) {
    return deny('RECENT_REJECTION', candidate.action);
  }
  if (context.time_since_last_intervention_sec === null ||
      !Number.isFinite(context.time_since_last_intervention_sec) ||
      context.time_since_last_intervention_sec < COOLDOWN_SEC) {
    return deny('COOLDOWN', candidate.action);
  }
  if (candidate.action === 'suggest' &&
      !context.explicit_consent_this_time && !context.user_requested_help) {
    return deny('CURRENT_CONSENT_REQUIRED', candidate.action);
  }
  return { outcome: candidate.action === 'ask' ? 'ALLOW_ASK' : 'ALLOW_SUGGEST',
    reason_codes: ['G0_REPLAY_ALLOW'], candidate_action: candidate.action,
    gate_version: VERSION, gate_passed: true, executed: false };
}
