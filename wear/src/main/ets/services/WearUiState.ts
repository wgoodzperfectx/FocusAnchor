/** UI-only projections. They do not choose a Task when the phone projection is ambiguous. */
export interface WearStepLike {
  actionId?: string;
  revision?: number;
  text: string;
  status: string;
}

export interface WearTaskLike {
  id: string;
  completed: boolean;
  focusStep?: WearStepLike;
}

export function selectCurrentAction<T extends WearTaskLike>(tasks: T[], currentActionId?: string): T | undefined {
  const candidates = tasks.filter((task: T) => !task.completed &&
    !!task.focusStep?.actionId && !!task.focusStep?.revision &&
    task.focusStep.status !== 'completed');
  if (currentActionId) {
    const exact = candidates.filter((task: T) => task.focusStep?.actionId === currentActionId);
    return exact.length === 1 ? exact[0] : undefined;
  }
  const active = candidates.filter((task: T) => task.focusStep?.status === 'in_progress' ||
    task.focusStep?.status === 'paused');
  if (active.length > 0) return active.length === 1 ? active[0] : undefined;
  const ready = candidates.filter((task: T) => task.focusStep?.status === 'ready');
  return ready.length === 1 ? ready[0] : undefined;
}

export function primaryStepEvent(status: string, paused: boolean): 'start' | 'pause' | 'resume' {
  if (paused || status === 'paused') return 'resume';
  return status === 'in_progress' ? 'pause' : 'start';
}

export type WearMonitorState = 'CONNECTING' | 'READING' | 'MONITORING' |
  'SIGNAL_UNSTABLE' | 'RECONNECTING' | 'STOPPED' | 'UNKNOWN';

export type WearInteractionState = 'IDLE' | 'LISTENING' | 'BREAKING_DOWN' | 'AWAITING_CONFIRMATION' |
  'FIRST_STEP' | 'IN_PROGRESS' | 'PAUSED' | 'STEP_COMPLETE';

export type WearCompanionState = 'STABLE' | 'FLUCTUATING' | 'SUPPORT_REQUESTED' | 'UNKNOWN';

/** P1 interaction art selected by the real UI state; no timing or random rotation. */
export function interactionVisualId(state: WearInteractionState): string {
  switch (state) {
    case 'LISTENING': return 'status_listening';
    case 'BREAKING_DOWN': return 'status_breaking_down';
    case 'AWAITING_CONFIRMATION': return 'status_awaiting_confirmation';
    case 'FIRST_STEP': return 'status_first_step';
    case 'IN_PROGRESS': return 'status_in_progress';
    case 'PAUSED': return 'status_paused';
    case 'STEP_COMPLETE': return 'status_step_complete';
    default: return 'status_ready';
  }
}

/** P3 user state is consumed only when a trusted producer supplies it. */
export function companionVisualId(state: WearCompanionState): string {
  switch (state) {
    case 'STABLE': return 'fa_companion_stable';
    case 'FLUCTUATING': return 'fa_companion_fluctuating';
    case 'SUPPORT_REQUESTED': return 'fa_companion_support_requested';
    default: return 'status_ready';
  }
}

export function companionStateLabel(state: WearCompanionState, chinese: boolean): string {
  if (state === 'STABLE') return chinese ? '专注稳定' : 'Focus stable';
  if (state === 'FLUCTUATING') return chinese ? '状态波动' : 'State fluctuating';
  if (state === 'SUPPORT_REQUESTED') return chinese ? '需要小步伙伴' : 'Support requested';
  return chinese ? '用户状态未知' : 'User state unavailable';
}

/** Read-only handoff shape for the device owner. No producer is connected in V3.2. */
export interface WearMonitorSnapshot {
  state: WearMonitorState;
  source: 'REAL' | 'SIMULATED';
  updatedAt: number;
}

export function resolveMonitorSnapshot(snapshot: WearMonitorSnapshot | undefined, now: number):
  { state: WearMonitorState; source: 'REAL' | 'SIMULATED' | 'UNAVAILABLE' } {
  if (!snapshot || !['CONNECTING', 'READING', 'MONITORING', 'SIGNAL_UNSTABLE',
    'RECONNECTING', 'STOPPED'].includes(snapshot.state) ||
    (snapshot.source !== 'REAL' && snapshot.source !== 'SIMULATED') ||
    typeof snapshot.updatedAt !== 'number' || snapshot.updatedAt > now ||
    now - snapshot.updatedAt > 60_000) {
    return { state: 'UNKNOWN', source: 'UNAVAILABLE' };
  }
  return { state: snapshot.state, source: snapshot.source };
}

export function monitorVisualId(state: WearMonitorState): string {
  switch (state) {
    case 'CONNECTING': return 'fa_monitor_connecting';
    case 'READING': return 'fa_monitor_reading';
    case 'MONITORING': return 'fa_monitor_monitoring';
    case 'SIGNAL_UNSTABLE': return 'fa_monitor_signal_unstable';
    case 'RECONNECTING': return 'fa_monitor_reconnecting';
    case 'STOPPED': return 'fa_monitor_stopped';
    default: return 'status_ready';
  }
}

export function monitorStateLabel(state: WearMonitorState, chinese: boolean): string {
  const zh: Record<WearMonitorState, string> = {
    CONNECTING: '正在连接', READING: '正在读取', MONITORING: '监测中',
    SIGNAL_UNSTABLE: '信号异常', RECONNECTING: '重新连接', STOPPED: '已停止', UNKNOWN: '状态未知'
  };
  const en: Record<WearMonitorState, string> = {
    CONNECTING: 'Connecting', READING: 'Reading', MONITORING: 'Monitoring',
    SIGNAL_UNSTABLE: 'Signal unstable', RECONNECTING: 'Reconnecting', STOPPED: 'Stopped',
    UNKNOWN: 'Status unknown'
  };
  return chinese ? zh[state] : en[state];
}

export function monitorSourceLabel(source: 'REAL' | 'SIMULATED' | 'UNAVAILABLE',
  chinese: boolean): string {
  if (source === 'REAL') return chinese ? '设备数据' : 'Device data';
  if (source === 'SIMULATED') return chinese ? '模拟数据 · 不推断专注' : 'Simulated · no focus inference';
  return chinese ? '设备状态未提供' : 'Device status unavailable';
}

export type WearFlashUiState = 'IDLE' | 'LOCAL' | 'PENDING' | 'SYNCED' | 'SAVE_FAILED' | 'SYNC_FAILED';

export function flashUiLabel(state: WearFlashUiState, chinese: boolean): string {
  if (chinese) {
    switch (state) {
      case 'LOCAL': return '已保存在手表';
      case 'PENDING': return '已保存在手表 · 等待同步';
      case 'SYNCED': return '同步已确认';
      case 'SAVE_FAILED': return '保存失败';
      case 'SYNC_FAILED': return '已保存在手表 · 同步失败';
      default: return '';
    }
  }
  switch (state) {
    case 'LOCAL': return 'Saved on watch';
    case 'PENDING': return 'Saved on watch · waiting to sync';
    case 'SYNCED': return 'Sync confirmed';
    case 'SAVE_FAILED': return 'Save failed';
    case 'SYNC_FAILED': return 'Saved on watch · sync failed';
    default: return '';
  }
}

/** KV acceptance means queued, never ACK-confirmed. A retry after failure returns to pending. */
export function flashTransportState(accepted: boolean): 'PENDING' | 'SYNC_FAILED' {
  return accepted ? 'PENDING' : 'SYNC_FAILED';
}
