export const SCHEMA_VERSION = '2.1.0';
export interface WorkflowEvent {
  schemaVersion: '2.1.0'; eventId: string; correlationId: string;
  channel: 'USER'|'CONTEXT'; type: string; source: string; occurredAt: string; expiresAt: string;
  payload: { title?: string; text?: string; taskId?: string; storageConfirmed?: boolean; companionAction?: string };
  consent: { scopeIds: string[]; grantIds: string[]; checkedAt: string; version: number };
  provenance: { adapterId: string; adapterVersion: string; sourceEventId?: string };
}
export interface ContextFeatures {
  schemaVersion: '2.1.0'; contextId: string; timestamp: string;
  taskContext: { candidateTaskId?: string; candidateStepId?: string; candidateReferenceId?: string; candidateSource?: 'existing_task'|'user_confirmed_memory'; candidateEvidenceIds: string[] };
  temporalContext: { localTime: string; deadlineAt?: string; quietHours: boolean };
  optionalLocationContext?: { sceneCode: string; quality: string; sourceId: string };
  optionalBehaviorFeatures?: { featureCodes: string[]; sourceIds: string[] };
  optionalPhysiologicalFeatures?: { abstractCodes: string[]; sourceIds: string[]; quality: string };
  dataQuality: 'sufficient'|'partial'|'insufficient'; evidenceSources: string[]; missingFields: string[];
}
export interface InterventionDecision {
  schemaVersion: '2.1.0'; decisionId: string; contextId: string;
  decision: 'INTERVENE'|'DEFER'|'ASK'|'ABSTAIN'; policyVersion: string;
  reasonCodes: string[]; evidenceReferences: string[];
  suggestedActionType: 'resume_step'|'activate_candidate'|'clarify'|'none'; optionalDeferUntil?: string;
  score?: { value: number; semantics: string; calibration: 'uncalibrated'|'calibrated' };
}
export interface PlanStep { stepId: string; order: number; text: string; status: 'proposed'|'ready'|'in_progress'|'paused'|'completed'|'blocked'; estimatedStartMinutes: 1|2; }
export interface TaskPlan { schemaVersion: '2.1.0'; planId: string; planRevision: number; taskId?: string; title: string; userGoal: string; steps: PlanStep[]; firstStepId: string; sourceEventId: string; plannerProvider: string; plannerVersion: string; }
export interface FirstStepCard { schemaVersion: '2.1.0'; cardId: string; taskId: string; actionId: string; actionRevision: number; stepId: string; title: string; action: string; expiresAt: string; choices: string[]; }
export type ConfirmationChoice = 'accept'|'modify'|'reject'|'pause';
export interface ConfirmationEvent { eventId: string; planId: string; planRevision: number; actor: 'user'; choice: ConfirmationChoice; timestamp: string; requestedEdit?: string; }
export interface DeliveryReceipt { receiptId: string; actionId: string; target: 'phone'|'watch'; status: 'queued'|'sent'|'delivered'|'failed'|'offline'; transportVersion: string; timestamp: string; errorCode?: string; }
export interface FeedbackEvent { eventId: string; relatedDecisionId?: string; relatedActionId?: string; timestamp: string; feedbackType: 'accepted'|'rejected'|'paused'|'start_confirmed'|'completion_reported'|'corrected'|'silent'; feedbackSource: 'phone'|'watch'|'card'; observationStatus: 'user_reported'|'device_observed'|'not_observed'; }
export interface ProviderInfo { id: string; kind: 'mock'|'real'; version: string; capability: 'available'|'planned'|'deferred'|'blocked'; prerequisites: string[]; }
export interface ActionShape { taskId: string; actionId: string; text: string; status: 'ready'|'in_progress'|'completed'; order: number; updatedAt: number; revision: number; generationSource: 'agent'|'rule'|'manual'|'legacy'; appliedEventIds?: string[]; }
export interface WorkflowTask { id: string; title: string; content: string; completed: boolean; createdAt: number; planId: string; planRevision: number; focusStep: ActionShape; }
export interface WorkflowResult { status: string; reason?: string; plan?: TaskPlan; card?: FirstStepCard; suggestionId?: string; message?: string; }
export interface Draft { plan: TaskPlan; event: WorkflowEvent; state: string; decisionId?: string; result?: WorkflowResult; }
export interface ConfirmedCandidate { referenceId: string; title: string; evidenceId: string; userConfirmed: boolean; }
export interface Suggestion { id: string; event: WorkflowEvent; decision: InterventionDecision; candidateTaskId?: string; candidate?: ConfirmedCandidate; state: string; responseEventId?: string; responseResult?: WorkflowResult; }
export interface OutboxItem { card: FirstStepCard; event: WorkflowEvent; status: string; }
export interface WorkflowData {
  schemaVersion: '2.1.0'; tasks: WorkflowTask[]; drafts: Draft[]; suggestions: Suggestion[];
  schedules: { id: string; event: WorkflowEvent; dueAt: string; state: string }[];
  outbox: OutboxItem[]; receipts: DeliveryReceipt[]; feedback: FeedbackEvent[];
  audit: { eventId: string; correlationId: string; status: string; reason?: string; timestamp: string; providerId?: string; providerVersion?: string; contextId?: string; decisionId?: string; evidenceReferences?: string[]; consentVersion?: number }[];
  processed: { key: string; fingerprint: string; result: WorkflowResult }[];
  confirmations: { key: string; fingerprint: string; timestamp?: string; result: WorkflowResult }[];
  sandbox: { eventId: string; text: string; timestamp: string }[];
  controls: { paused: boolean; suppressed: boolean };
}
export interface TaskStore { info: ProviderInfo; read(): Promise<WorkflowData>; transact<T>(work: (data: WorkflowData) => T): Promise<T>; }
export interface GateSnapshot { allowed: boolean; version: number; validSource: boolean; quietHours: boolean; frequencyAllowed: boolean; allowAsk: boolean; sandboxAllowed: boolean; scopes: string[]; }
export interface ModelProvider { info: ProviderInfo; }
export interface WorkflowDeps {
  now: () => number; timeoutMs: number; store: TaskStore;
  authorize: (event: WorkflowEvent) => Promise<GateSnapshot>;
  planner: ModelProvider & { plan(input: { event: WorkflowEvent; existing?: WorkflowTask; previous?: TaskPlan; edit?: string }): Promise<unknown> };
  estimator: ModelProvider & { estimate(event: WorkflowEvent): Promise<unknown> };
  policy: ModelProvider & { decide(context: ContextFeatures): Promise<unknown> };
  device: ModelProvider & { send(card: FirstStepCard): Promise<unknown> };
  schedulerAvailable: boolean;
  resolveCandidate?(referenceId: string): Promise<ConfirmedCandidate | undefined>;
}
export function emptyWorkflowData(): WorkflowData {
  return { schemaVersion: '2.1.0', tasks: [], drafts: [], suggestions: [], schedules: [], outbox: [], receipts: [], feedback: [], audit: [], processed: [], confirmations: [], sandbox: [], controls: { paused: false, suppressed: false } };
}
