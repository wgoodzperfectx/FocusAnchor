import test from 'node:test';
import assert from 'node:assert/strict';
import { selectCompanionVisual } from '../entry/src/main/ets/services/CompanionLogic.ts';

test('all six monitoring states have distinct visual IDs', () => {
  const states = ['CONNECTING', 'READING', 'MONITORING', 'SIGNAL_UNSTABLE', 'RECONNECTING', 'STOPPED'];
  const ids = states.map(monitoringState => selectCompanionVisual({ monitoringState,
    isSimulated: false, bpm: 72, measuredAt: 100 }, 100));
  assert.equal(new Set(ids).size, 6);
});

test('simulated and stale samples never claim stable companion', () => {
  assert.equal(selectCompanionVisual({ monitoringState: 'MONITORING', companionState: 'STABLE',
    isSimulated: true, bpm: 72, measuredAt: 100 }, 100), 'fa_monitor_monitoring');
  assert.equal(selectCompanionVisual({ monitoringState: 'MONITORING', companionState: 'STABLE',
    isSimulated: false, bpm: 72, measuredAt: 1 }, 120_001), 'fa_monitor_reading');
});

test('trusted fresh companion states have distinct IDs', () => {
  const states = ['STABLE', 'FLUCTUATING', 'SUPPORT_REQUESTED'];
  const ids = states.map(companionState => selectCompanionVisual({ monitoringState: 'MONITORING',
    companionState, isSimulated: false, bpm: 72, measuredAt: 100 }, 100));
  assert.equal(new Set(ids).size, 3);
});
