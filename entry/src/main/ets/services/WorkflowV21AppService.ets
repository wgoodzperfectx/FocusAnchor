import { common } from '@kit.AbilityKit';
import { StudyTask } from '../models/AppTypes';
import { normalizeFocusAction } from './ActionLogic';
import { TaskFileService } from './TaskFileService';
import { ConfirmationChoice, WorkflowEvent, WorkflowResult, WorkflowTask } from './WorkflowV21Contracts';
import { createMockRuntime } from './WorkflowV21Mocks';
import { WorkflowV21 } from './WorkflowV21Router';
import { WorkflowV21Store } from './WorkflowV21Store';

/** Opt-in phone bridge. All providers are local mocks; no real device transport is called. */
export class WorkflowV21AppService {
  private static sequence: number = 0;
  private store: WorkflowV21Store;
  private workflow: WorkflowV21;
  private taskFile: TaskFileService;
  private consent: () => boolean;
  private consentVersion: () => number;
  private tail: Promise<void> = Promise.resolve();

  constructor(context: common.Context, taskFile: TaskFileService, consent: () => boolean, consentVersion: () => number = (): number => 1) {
    this.store = new WorkflowV21Store(context);
    this.taskFile = taskFile;
    this.consent = consent;
    this.consentVersion = consentVersion;
    const runtime = createMockRuntime(Date.now(), this.store);
    // An offline mock receipt cannot be mistaken for an observed watch delivery.
    runtime.device.mode = 'offline';
    runtime.deps.now = (): number => Date.now();
    runtime.deps.schedulerAvailable = false;
    runtime.deps.authorize = async (event: WorkflowEvent) => ({
      allowed: this.consent() === true,
      version: this.consentVersion(),
      validSource: event.source === 'phone' && event.provenance.adapterId === 'phone-local-v21',
      quietHours: false,
      frequencyAllowed: true,
      allowAsk: false,
      sandboxAllowed: false,
      scopes: this.consent() === true ? ['focus_support'] : []
    });
    this.workflow = new WorkflowV21(runtime.deps);
  }

  private serial<T>(work: () => Promise<T>): Promise<T> {
    const next = this.tail.then(work, work);
    this.tail = next.then((): void => {}, (): void => {});
    return next;
  }

  private blocked(): WorkflowResult {
    return { status: 'BLOCKED', reason: 'CONSENT_REQUIRED_OR_REVOKED' };
  }

  propose(title: string, text: string, taskId?: string): Promise<WorkflowResult> {
    return this.serial(async (): Promise<WorkflowResult> => {
      if (this.consent() !== true) {
        return this.blocked();
      }
      try {
        let existing: StudyTask | undefined;
        if (taskId) {
          existing = (await this.taskFile.loadTasks()).find((task: StudyTask) => task.id === taskId && !task.completed);
          if (!existing) {
            return { status: 'AWAITING_CLARIFICATION', reason: 'NO_RELIABLE_TASK' };
          }
        }
        const action = existing ? normalizeFocusAction(existing) : undefined;
        if (existing && action) {
          const canonical = existing;
          await this.store.transact(data => {
            const previous = data.tasks.find(task => task.id === canonical.id);
            const seeded: WorkflowTask = {
              id: canonical.id, title: canonical.title, content: canonical.content,
              completed: canonical.completed, createdAt: canonical.createdAt,
              planId: previous?.planId ?? `legacy_${canonical.id}`,
              planRevision: previous?.planRevision ?? 0, focusStep: action
            };
            data.tasks = [...data.tasks.filter(task => task.id !== canonical.id), seeded];
          });
        }
        const now = Date.now();
        const eventId = `phone_v21_${now}_${++WorkflowV21AppService.sequence}`;
        const effectiveTitle = (existing?.title ?? title).trim() || (existing?.content ?? text).trim();
        const event: WorkflowEvent = {
          schemaVersion: '2.1.0', eventId, correlationId: eventId,
          channel: 'USER', type: action ? 'resume_task' : 'create_task', source: 'phone',
          occurredAt: new Date(now).toISOString(), expiresAt: new Date(now + 10 * 60 * 1000).toISOString(),
          payload: { title: effectiveTitle, text: existing?.content ?? text, taskId },
          consent: { scopeIds: ['focus_support'], grantIds: [`phone-local-focus-opt-in_${this.consentVersion()}`],
            checkedAt: new Date(now).toISOString(), version: this.consentVersion() },
          provenance: { adapterId: 'phone-local-v21', adapterVersion: '2.1.0-local-mock' }
        };
        return await this.workflow.dispatch(event);
      } catch (_) {
        return { status: 'FAILED_SAFE', reason: 'LOCAL_WORKFLOW_UNAVAILABLE' };
      }
    });
  }

  confirm(planId: string, revision: number, choice: ConfirmationChoice, edit?: string): Promise<WorkflowResult> {
    return this.serial(async (): Promise<WorkflowResult> => {
      if (this.consent() !== true) {
        return this.blocked();
      }
      try {
        const eventId = `phone_v21_confirm_${encodeURIComponent(planId)}_${revision}_${choice}`;
        const state = await this.store.read();
        const draft = state.drafts.find(item => item.plan.planId === planId);
        if (draft && draft.event.consent.version !== this.consentVersion()) { return this.blocked(); }
        const prior = state.confirmations.find(item => item.key === eventId);
        const result = await this.workflow.confirm({
          eventId, planId, planRevision: revision, actor: 'user', choice,
          requestedEdit: edit, timestamp: prior?.timestamp ?? new Date().toISOString()
        });
        if (choice !== 'accept' || !result.card || !['DELIVERED', 'SYNC_RETRYABLE'].includes(result.status)) {
          return result;
        }
        try {
          await this.restoreInternal();
        } catch (_) {
          return { status: 'FAILED_SAFE', reason: 'TASK_PROJECTION_FAILED', card: result.card };
        }
        return { status: 'LOCAL_CONFIRMED', reason: 'MOCK_ONLY_REAL_DEVICE_UNVERIFIED', card: result.card,
          message: '已在本地确认；等待真机交付验证。' };
      } catch (_) {
        return { status: 'FAILED_SAFE', reason: 'LOCAL_WORKFLOW_UNAVAILABLE' };
      }
    });
  }

  /** Replay only accepted, unprojected plans; never replay a mock delivery into real transport. */
  restoreProjection(): Promise<boolean> {
    return this.serial(async (): Promise<boolean> => this.consent() === true ? this.restoreInternal() : false);
  }

  private projectionId(task: WorkflowTask): string {
    return `projection_${encodeURIComponent(task.id)}_${encodeURIComponent(task.planId)}_${task.planRevision}`;
  }

  private async restoreInternal(): Promise<boolean> {
    if (this.consent() !== true) {
      return false;
    }
    const data = await this.store.read();
    const pending = data.tasks.filter(task =>
      data.drafts.some(draft => draft.state === 'accepted' && draft.event.consent.version === this.consentVersion() && draft.plan.planId === task.planId && draft.plan.planRevision === task.planRevision) &&
      !data.audit.some(entry => entry.eventId === this.projectionId(task) && entry.status === 'LOCAL_PROJECTED'));
    if (pending.length === 0) {
      return false;
    }
    await this.taskFile.withExclusive(async (): Promise<void> => {
      const tasks = await this.taskFile.loadTasks();
      if (this.consent() !== true) {
        throw new Error('CONSENT_REQUIRED_OR_REVOKED');
      }
      let changed = false;
      pending.forEach((task: WorkflowTask): void => {
        const index = tasks.findIndex((current: StudyTask) => current.id === task.id);
        const existing = index >= 0 ? tasks[index] : undefined;
        const action = existing ? normalizeFocusAction(existing) : undefined;
        // A card/watch update committed after confirmation remains canonical.
        if (existing?.completed || (action && (action.updatedAt > task.focusStep.updatedAt ||
          (action.actionId === task.focusStep.actionId && action.revision > task.focusStep.revision)))) {
          return;
        }
        // tasks.json is JSON data. Clone its full record to preserve old optional
        // and extension metadata while keeping the ArkTS projection explicit.
        const projected: StudyTask = existing ? JSON.parse(JSON.stringify(existing)) as StudyTask : {
          id: task.id, title: task.title, content: task.content,
          studyMinutes: 25, studyMethod: 'reading', priority: 2, basePriority: 2,
          completed: task.completed, createdAt: task.createdAt
        };
        projected.id = task.id;
        projected.title = task.title;
        projected.content = task.content;
        projected.completed = task.completed;
        projected.createdAt = existing?.createdAt ?? task.createdAt;
        projected.focusStep = {
          taskId: task.focusStep.taskId,
          actionId: task.focusStep.actionId,
          text: task.focusStep.text,
          status: task.focusStep.status,
          order: task.focusStep.order,
          updatedAt: task.focusStep.updatedAt,
          revision: task.focusStep.revision,
          generationSource: task.focusStep.generationSource,
          appliedEventIds: task.focusStep.appliedEventIds?.slice()
        };
        if (JSON.stringify(existing) === JSON.stringify(projected)) {
          return;
        }
        if (index >= 0) {
          tasks[index] = projected;
        } else {
          tasks.push(projected);
        }
        changed = true;
      });
      if (changed) {
        await this.taskFile.saveTasks(tasks);
      }
    });
    // Mark after tasks.json commits. A crash between writes safely replays the same Action.
    await this.store.transact(state => {
      pending.forEach(task => {
        const eventId = this.projectionId(task);
        if (!state.audit.some(entry => entry.eventId === eventId && entry.status === 'LOCAL_PROJECTED')) {
          state.audit.push({ eventId, correlationId: task.planId, status: 'LOCAL_PROJECTED', timestamp: new Date().toISOString() });
        }
      });
    });
    return true;
  }
}
