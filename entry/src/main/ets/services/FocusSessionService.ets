import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { FocusSession } from '../models/AppTypes';
import { transitionFocusSession } from './FocusSessionLogic';

const PREF_NAME: string = 'focus_anchor_session';
const SESSION_KEY: string = 'current_session';

/** The session is local state bound to an Action; pause never completes the Action. */
export class FocusSessionService {
  static async load(context: common.Context): Promise<FocusSession | undefined> {
    const store = await preferences.getPreferences(context, PREF_NAME);
    const raw = await store.get(SESSION_KEY, '');
    if (typeof raw !== 'string' || !raw) {
      return undefined;
    }
    try {
      return JSON.parse(raw) as FocusSession;
    } catch (error) {
      return undefined;
    }
  }

  static async transition(context: common.Context, taskId: string, actionId: string,
    operation: 'start' | 'pause' | 'resume', eventId?: string): Promise<FocusSession | undefined> {
    const current = await FocusSessionService.load(context);
    const next = transitionFocusSession(current, taskId, actionId, operation, Date.now(), eventId);
    if (!next) {
      return undefined;
    }
    const store = await preferences.getPreferences(context, PREF_NAME);
    await store.put(SESSION_KEY, JSON.stringify(next));
    await store.flush();
    return next;
  }

  static async finish(context: common.Context, taskId: string, actionId: string): Promise<void> {
    const current = await FocusSessionService.load(context);
    if (!current || current.taskId !== taskId || current.actionId !== actionId) {
      return;
    }
    const store = await preferences.getPreferences(context, PREF_NAME);
    const finished: FocusSession = {
      sessionId: current.sessionId,
      taskId: current.taskId,
      actionId: current.actionId,
      status: 'IDLE',
      updatedAt: Date.now(),
      appliedEventIds: current.appliedEventIds
    };
    await store.put(SESSION_KEY, JSON.stringify(finished));
    await store.flush();
  }
}
