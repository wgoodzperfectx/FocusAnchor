import type { ContextFeatures } from './WorkflowV21Contracts.ts';

const object = (v: unknown): v is Record<string, any> => v !== null && typeof v === 'object' && !Array.isArray(v);
const text = (v: unknown, max = 500): v is string => typeof v === 'string' && v.trim().length > 0 && v.length <= max;
const strings = (v: unknown): v is string[] => Array.isArray(v) && v.every(x => text(x));
const integer = (v: unknown): boolean => Number.isSafeInteger(v) && Number(v) > 0;
export const validTime = (v: unknown): v is string => typeof v === 'string' && /T.*(?:Z|[+-]\d\d:\d\d)$/.test(v) && Number.isFinite(Date.parse(v));
const versioned = (v: unknown): v is Record<string, any> => object(v) && v.schemaVersion === '2.1.0';
export function validateEvent(v: unknown): boolean {
  if (!versioned(v) || !text(v.eventId) || !text(v.correlationId) || !validTime(v.occurredAt) || !validTime(v.expiresAt) || Date.parse(v.expiresAt) <= Date.parse(v.occurredAt)) return false;
  const user = ['create_task','resume_task','capture_thought','focus_companion','card_feedback'];
  const context = ['time_due','deadline_due','behavior_pattern','location_scene','physiology_abstract'];
  if (!(v.channel === 'USER' && user.includes(v.type) && ['phone','watch_asr'].includes(v.source)) &&
      !(v.channel === 'CONTEXT' && context.includes(v.type) && ['app_scheduler','authorized_adapter'].includes(v.source))) return false;
  if (!object(v.consent) || !strings(v.consent.scopeIds) || !strings(v.consent.grantIds) || !integer(v.consent.version) || !validTime(v.consent.checkedAt)) return false;
  if (!object(v.provenance) || !text(v.provenance.adapterId) || !text(v.provenance.adapterVersion) || !object(v.payload)) return false;
  const allowed = ['title','text','taskId','storageConfirmed','companionAction'];
  if (!Object.keys(v.payload).every(k => allowed.includes(k))) return false;
  if (v.payload.title !== undefined && !text(v.payload.title, 120)) return false;
  if (v.payload.text !== undefined && !text(v.payload.text)) return false;
  if (v.payload.taskId !== undefined && !text(v.payload.taskId)) return false;
  if (v.payload.storageConfirmed !== undefined && typeof v.payload.storageConfirmed !== 'boolean') return false;
  return true;
}
export function validateContextFeatures(v: unknown): boolean {
  if (!versioned(v) || !text(v.contextId) || !validTime(v.timestamp) || !object(v.taskContext) || !object(v.temporalContext) || !validTime(v.temporalContext.localTime) || typeof v.temporalContext.quietHours !== 'boolean' || !strings(v.evidenceSources) || !strings(v.missingFields) || !strings(v.taskContext.candidateEvidenceIds) || !['sufficient','partial','insufficient'].includes(v.dataQuality)) return false;
  if (!v.taskContext.candidateEvidenceIds.every((x: string) => v.evidenceSources.includes(x))) return false;
  if (v.taskContext.candidateTaskId !== undefined && (!text(v.taskContext.candidateTaskId) || !['existing_task','user_confirmed_memory'].includes(v.taskContext.candidateSource) || !v.taskContext.candidateEvidenceIds.length)) return false;
  for (const name of ['optionalLocationContext','optionalBehaviorFeatures','optionalPhysiologicalFeatures']) {
    const feature = v[name];
    if (feature === undefined) { if (!v.missingFields.includes(name)) return false; continue; }
    if (!object(feature) || v.missingFields.includes(name)) return false;
    if (name === 'optionalLocationContext') {
      if (!text(feature.sceneCode) || !['observed','uncertain'].includes(feature.quality) || !v.evidenceSources.includes(feature.sourceId)) return false;
    } else {
      if (!strings(feature.sourceIds) || !feature.sourceIds.length || !feature.sourceIds.every((x: string) => v.evidenceSources.includes(x))) return false;
      if (!strings(feature[name === 'optionalBehaviorFeatures' ? 'featureCodes' : 'abstractCodes'])) return false;
      if (name === 'optionalPhysiologicalFeatures' && !['observed','uncertain'].includes(feature.quality)) return false;
    }
  }
  return true;
}
export function validateInterventionDecision(v: unknown, context: ContextFeatures): boolean {
  if (!versioned(v) || !text(v.decisionId) || v.contextId !== context.contextId || !text(v.policyVersion) || !strings(v.reasonCodes) || !v.reasonCodes.length || !strings(v.evidenceReferences) || !v.evidenceReferences.every((x: string) => context.evidenceSources.includes(x))) return false;
  if (!['INTERVENE','DEFER','ASK','ABSTAIN'].includes(v.decision) || !['resume_step','activate_candidate','clarify','none'].includes(v.suggestedActionType)) return false;
  if (v.decision === 'DEFER' && (!validTime(v.optionalDeferUntil) || Date.parse(v.optionalDeferUntil) <= Date.parse(context.timestamp))) return false;
  if (v.decision !== 'DEFER' && v.optionalDeferUntil !== undefined) return false;
  if (v.decision === 'ABSTAIN' && v.suggestedActionType !== 'none') return false;
  if (v.decision === 'ASK' && v.suggestedActionType !== 'clarify') return false;
  if (v.score !== undefined && (!object(v.score) || !Number.isFinite(v.score.value) || !text(v.score.semantics) || !['uncalibrated','calibrated'].includes(v.score.calibration))) return false;
  return true;
}
export function validateTaskPlan(v: unknown): boolean {
  if (!versioned(v) || !text(v.planId) || !integer(v.planRevision) || !text(v.title,120) || !text(v.userGoal) || !text(v.sourceEventId) || !text(v.plannerProvider) || !text(v.plannerVersion) || !Array.isArray(v.steps) || v.steps.length < 1 || v.steps.length > 50) return false;
  const seen = new Set<string>();
  for (let i = 0; i < v.steps.length; i++) {
    const s = v.steps[i];
    if (!object(s) || !text(s.stepId) || seen.has(s.stepId) || s.order !== i || !text(s.text) || !['proposed','ready','in_progress','paused','completed','blocked'].includes(s.status) || ![1,2].includes(s.estimatedStartMinutes)) return false;
    seen.add(s.stepId);
  }
  return v.steps.find((s: any) => s.status !== 'completed')?.stepId === v.firstStepId;
}
export function validateConfirmation(v: unknown): boolean {
  return object(v) && text(v.eventId) && text(v.planId) && integer(v.planRevision) && v.actor === 'user' && ['accept','modify','reject','pause'].includes(v.choice) && validTime(v.timestamp) && (v.choice !== 'modify' || text(v.requestedEdit));
}
export function validateDeliveryReceipt(v: unknown, actionId: string): boolean {
  return object(v) && text(v.receiptId) && v.actionId === actionId && ['phone','watch'].includes(v.target) && ['queued','sent','delivered','failed','offline'].includes(v.status) && text(v.transportVersion) && validTime(v.timestamp);
}
export function validateActionEvent(v: unknown): boolean {
  return object(v) && text(v.eventId) && text(v.taskId) && text(v.actionId) && integer(v.baseRevision) && ['start','resume','pause','complete','change'].includes(v.type) && ['phone','watch','card'].includes(v.origin) && Number.isFinite(v.createdAt);
}
