/** UI-only read contracts. Producers remain the Task/Action, Agent, device and sync owners. */
export type UiActionStatus = 'READY' | 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'UNKNOWN';
export type UiDataSource = 'REAL' | 'SIMULATED' | 'UNAVAILABLE';
export type UiMonitorState = 'CONNECTING' | 'READING' | 'MONITORING' |
  'SIGNAL_UNSTABLE' | 'RECONNECTING' | 'STOPPED' | 'UNKNOWN';
export type UiConnectionState = 'CONNECTED' | 'CONNECTING' | 'DISCONNECTED' | 'UNKNOWN';
export type UiFlashSyncState = 'LOCAL' | 'PENDING' | 'SYNCED' | 'FAILED' | 'UNKNOWN';

export interface UiCurrentAction {
  readonly taskId: string;
  readonly taskTitle: string;
  readonly actionId: string;
  readonly actionText: string;
  readonly revision: number;
  readonly status: UiActionStatus;
  readonly generationSource: 'AGENT' | 'RULE' | 'MANUAL' | 'LEGACY' | 'UNKNOWN';
  readonly updatedAt: number;
}

/** A provider result is a suggestion until the user confirms and the Action store acknowledges it. */
export type UiStepResult =
  | { readonly kind: 'STEP'; readonly requestId: string; readonly suggestionId: string;
      readonly text: string; readonly explanation?: string; readonly source: 'AGENT' }
  | { readonly kind: 'CLARIFY'; readonly requestId: string; readonly question: string;
      readonly choices?: readonly string[] }
  | { readonly kind: 'ERROR'; readonly requestId: string; readonly message: string;
      readonly retryable: boolean }
  | { readonly kind: 'FALLBACK'; readonly requestId: string; readonly text: string;
      readonly source: 'RULE' | 'MANUAL'; readonly reason: string };

export interface UiDeviceState {
  readonly connection: UiConnectionState;
  readonly monitor: UiMonitorState;
  readonly dataSource: UiDataSource;
  readonly measuredAt?: number;
  readonly bpm?: number;
  readonly detail?: string;
}

export interface UiFlashItem {
  readonly flashId: string;
  readonly content: string;
  readonly createdAt: number;
  readonly sourceDevice: 'WATCH' | 'PHONE' | 'UNKNOWN';
  readonly sync: UiFlashSyncState;
  readonly convertedTaskId?: string;
}

export interface UiCompanionState {
  readonly monitor: UiMonitorState;
  readonly companion: 'STABLE' | 'FLUCTUATING' | 'SUPPORT_REQUESTED' | 'UNKNOWN';
  readonly interaction: 'IDLE' | 'LOADING' | 'STEP' | 'CLARIFY' | 'ERROR' |
    'FALLBACK' | 'SAVED' | 'ACTIVE' | 'PAUSED' | 'COMPLETE' | 'FLASH_SAVED';
  readonly dataSource: UiDataSource;
}
