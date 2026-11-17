import { createMockRuntime } from '../entry/src/main/ets/services/WorkflowV21Mocks.ts';
import { WorkflowV21 } from '../entry/src/main/ets/services/WorkflowV21Router.ts';

export const NOW = Date.parse('2026-10-28T10:00:00+08:00');
export function event(type = 'create_task', extra = {}) {
  const context = ['time_due', 'deadline_due', 'behavior_pattern', 'location_scene', 'physiology_abstract'].includes(type);
  return {
    schemaVersion: '2.1.0', eventId: `event-${type}`, correlationId: `trace-${type}`,
    channel: context ? 'CONTEXT' : 'USER', type,
    source: context ? 'app_scheduler' : 'phone',
    occurredAt: new Date(NOW).toISOString(), expiresAt: new Date(NOW + 60000).toISOString(),
    payload: context ? {} : { title: '写报告', text: '写报告' },
    consent: { scopeIds: ['focus_support', 'proactive_nudges'], grantIds: ['grant-1'], checkedAt: new Date(NOW).toISOString(), version: 1 },
    provenance: { adapterId: context ? 'scheduler' : 'phone-ui', adapterVersion: '1.0' }, ...extra
  };
}
export function harness(store) {
  const runtime = createMockRuntime(NOW, store);
  return { ...runtime, workflow: new WorkflowV21(runtime.deps) };
}
export async function confirmed(h, e = event()) {
  const draft = await h.workflow.dispatch(e);
  return h.workflow.confirm({ eventId: `confirm-${e.eventId}`, planId: draft.plan.planId,
    planRevision: draft.plan.planRevision, actor: 'user', choice: 'accept', timestamp: new Date(NOW).toISOString() });
}
