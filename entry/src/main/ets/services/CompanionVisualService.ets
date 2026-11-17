/** Explicit resource mapping keeps the pure state selector testable in Node. */
export function companionVisualResource(id: string): Resource {
  switch (id) {
    case 'status_ready': return $r('app.media.status_ready');
    case 'status_listening': return $r('app.media.status_listening');
    case 'status_breaking_down': return $r('app.media.status_breaking_down');
    case 'status_awaiting_confirmation': return $r('app.media.status_awaiting_confirmation');
    case 'status_first_step': return $r('app.media.status_first_step');
    case 'status_in_progress': return $r('app.media.status_in_progress');
    case 'status_paused': return $r('app.media.status_paused');
    case 'status_step_complete': return $r('app.media.status_step_complete');
    case 'fa_monitor_connecting': return $r('app.media.fa_monitor_connecting');
    case 'fa_monitor_reading': return $r('app.media.fa_monitor_reading');
    case 'fa_monitor_monitoring': return $r('app.media.fa_monitor_monitoring');
    case 'fa_monitor_signal_unstable': return $r('app.media.fa_monitor_signal_unstable');
    case 'fa_monitor_reconnecting': return $r('app.media.fa_monitor_reconnecting');
    case 'fa_companion_stable': return $r('app.media.fa_companion_stable');
    case 'fa_companion_fluctuating': return $r('app.media.fa_companion_fluctuating');
    case 'fa_companion_support_requested': return $r('app.media.fa_companion_support_requested');
    default: return $r('app.media.fa_monitor_stopped');
  }
}
