/** Resource IDs mirror the formal companion artwork; no monitoring inference occurs here. */
export function wearVisualResource(id: string): Resource {
  switch (id) {
    case 'fa_monitor_connecting': return $r('app.media.fa_monitor_connecting');
    case 'fa_monitor_reading': return $r('app.media.fa_monitor_reading');
    case 'fa_monitor_monitoring': return $r('app.media.fa_monitor_monitoring');
    case 'fa_monitor_signal_unstable': return $r('app.media.fa_monitor_signal_unstable');
    case 'fa_monitor_reconnecting': return $r('app.media.fa_monitor_reconnecting');
    case 'fa_monitor_stopped': return $r('app.media.fa_monitor_stopped');
    default: return $r('app.media.status_ready');
  }
}
