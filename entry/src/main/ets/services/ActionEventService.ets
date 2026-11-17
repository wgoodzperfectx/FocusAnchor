import { common } from '@kit.AbilityKit';
import { ActionEvent, ActionEventResult, StudyTask } from '../models/AppTypes';
import { applyActionEventToTasks } from './ActionLogic';
import { TaskFileService } from './TaskFileService';
import { WatchSyncService } from './WatchSyncService';
import { FocusCardService } from './FocusCardService';
import { FocusSessionService } from './FocusSessionService';

/** The phone is the sole writer that adjudicates Action transitions. */
export class ActionEventService {
  static async apply(context: common.Context, event: ActionEvent): Promise<ActionEventResult> {
    const file = TaskFileService.getInstance();
    file.init(context);
    return await file.withExclusive(async (): Promise<ActionEventResult> => {
      const tasks = await file.loadTasks();
      const reduction = applyActionEventToTasks<StudyTask>(tasks, event);
      if (reduction.status === 'session_only') {
        const session = await FocusSessionService.transition(context, event.taskId, event.actionId,
          event.type === 'resume' ? 'resume' : 'pause', event.eventId);
        return { status: session ? 'session_only' : 'conflict', currentRevision: reduction.currentRevision };
      }
      if (reduction.status !== 'applied') {
        return { status: reduction.status, currentRevision: reduction.currentRevision };
      }
      // A failed write must never be reported as success or published to other surfaces.
      await file.saveTasks(reduction.tasks);
      if (event.type === 'start') {
        await FocusSessionService.transition(context, event.taskId, event.actionId, 'start', event.eventId);
      } else if (event.type === 'complete') {
        await FocusSessionService.finish(context, event.taskId, event.actionId);
      }
      const watch = WatchSyncService.getInstance();
      await watch.init(context);
      await watch.pushTasksToWatch(reduction.tasks);
      await FocusCardService.refresh(context, reduction.tasks);
      return { status: 'applied', currentRevision: reduction.currentRevision };
    });
  }
}
