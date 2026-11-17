import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { StudyTask } from '../models/AppTypes';
import { TaskFileService } from './TaskFileService';
import { WatchSyncService } from './WatchSyncService';

const FORM_PREF: string = 'focus_anchor_forms';
const FORM_IDS: string = 'ids';

/** Bridges installed cards to the canonical task file and watch KV channel. */
export class FocusCardService {
  static async add(context: common.Context, formId: string): Promise<void> {
    const ids = await FocusCardService.ids(context);
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      await FocusCardService.saveIds(context, ids);
    }
  }

  static async remove(context: common.Context, formId: string): Promise<void> {
    await FocusCardService.saveIds(context, (await FocusCardService.ids(context)).filter((id: string) => id !== formId));
  }

  static binding(tasks: StudyTask[]): formBindingData.FormBindingData {
    const task = tasks.find((item: StudyTask) => !item.completed && !!item.focusStep &&
      item.focusStep.status !== 'completed') ??
      tasks.find((item: StudyTask) => !item.completed && !!item.focusStep);
    return formBindingData.createFormBindingData({
      taskTitle: task?.title ?? '今天准备开始什么？',
      stepText: task?.focusStep?.text ?? '打开应用，选择一个小行动',
      stepStatus: task?.focusStep?.status ?? 'empty',
      taskId: task?.id ?? '',
      actionId: task?.focusStep?.actionId ?? '',
      revision: task?.focusStep?.revision ?? 0
    });
  }

  static async refresh(context: common.Context, tasks: StudyTask[]): Promise<void> {
    const binding = FocusCardService.binding(tasks);
    let formIds: string[] = [];
    try {
      formIds = await FocusCardService.ids(context);
    } catch (error) {
      console.error('Focus card registry unavailable');
      return;
    }
    for (const id of formIds) {
      try {
        await formProvider.updateForm(id, binding);
      } catch (error) {
        console.error('Focus card refresh failed');
      }
    }
  }

  /** Publish the rule proposal invoked by the Agent extension without replacing an active step. */
  static async publishAgentStep(context: common.Context, taskId: string, stepText: string): Promise<void> {
    const file = TaskFileService.getInstance();
    file.init(context);
    await file.withExclusive(async (): Promise<void> => {
      const tasks = await file.loadTasks();
      const task = tasks.find((item: StudyTask) => item.id === taskId && !item.completed);
      if (!task || task.focusStep || stepText.trim().length === 0) {
        return;
      }
      const stamp = Date.now();
      task.focusStep = {
        taskId: task.id,
        actionId: `rule_${encodeURIComponent(task.id)}_${stamp}`,
        text: stepText.trim(),
        status: 'ready',
        order: 0,
        revision: 1,
        generationSource: 'rule',
        updatedAt: stamp
      };
      await file.saveTasks(tasks);
      const watch = WatchSyncService.getInstance();
      await watch.init(context);
      await watch.pushTasksToWatch(tasks);
      await FocusCardService.refresh(context, tasks);
    });
  }

  private static async ids(context: common.Context): Promise<string[]> {
    const store = await preferences.getPreferences(context, FORM_PREF);
    const raw = await store.get(FORM_IDS, '[]');
    try {
      const ids = JSON.parse(`${raw}`) as string[];
      return Array.isArray(ids) ? ids : [];
    } catch (error) {
      return [];
    }
  }

  private static async saveIds(context: common.Context, ids: string[]): Promise<void> {
    const store = await preferences.getPreferences(context, FORM_PREF);
    await store.put(FORM_IDS, JSON.stringify(ids));
    await store.flush();
  }
}
