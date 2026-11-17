export type MonitoringState = 'CONNECTING' | 'READING' | 'MONITORING' |
  'SIGNAL_UNSTABLE' | 'RECONNECTING' | 'STOPPED';
export type CompanionState = 'STABLE' | 'FLUCTUATING' | 'SUPPORT_REQUESTED' | 'UNKNOWN';

export interface StateSnapshot {
  monitoringState: MonitoringState;
  companionState?: CompanionState;
  bpm?: number;
  measuredAt?: number;
  isSimulated: boolean;
}

/** A monitoring fault, simulation, or stale sample takes precedence over companionship. */
export function selectCompanionVisual(snapshot: StateSnapshot, now: number = Date.now()): string {
  const monitoring: Record<MonitoringState, string> = {
    CONNECTING: 'fa_monitor_connecting',
    READING: 'fa_monitor_reading',
    MONITORING: 'fa_monitor_monitoring',
    SIGNAL_UNSTABLE: 'fa_monitor_signal_unstable',
    RECONNECTING: 'fa_monitor_reconnecting',
    STOPPED: 'fa_monitor_stopped'
  };
  if (snapshot.monitoringState !== 'MONITORING') {
    return monitoring[snapshot.monitoringState];
  }
  if (snapshot.isSimulated) {
    return 'fa_monitor_monitoring';
  }
  if (snapshot.bpm === undefined || snapshot.measuredAt === undefined ||
    now - snapshot.measuredAt > 60_000 || now < snapshot.measuredAt) {
    return 'fa_monitor_reading';
  }
  if (snapshot.companionState === 'STABLE') {
    return 'fa_companion_stable';
  }
  if (snapshot.companionState === 'FLUCTUATING') {
    return 'fa_companion_fluctuating';
  }
  if (snapshot.companionState === 'SUPPORT_REQUESTED') {
    return 'fa_companion_support_requested';
  }
  return 'fa_monitor_monitoring';
}
