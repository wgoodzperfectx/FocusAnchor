import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AgentDecision, FocusAnchorSession, ThoughtRecord } from './FocusAnchorSession';

const PREF_NAME = 'focux_anchor_store';
const SESSION_KEY = 'agent_session_v1';

interface SessionSnapshot {
  companionPaused: boolean;
  thoughts: ThoughtRecord[];
  lastText: string;
}

export class FocusAnchorStore {
  static async hydrate(context: common.Context): Promise<void> {
    try {
      const preferencesStore = await preferences.getPreferences(context, PREF_NAME);
      const raw = await preferencesStore.get(SESSION_KEY, '') as string;
      if (!raw) {
        return;
      }
      const snapshot = JSON.parse(raw) as SessionSnapshot;
      const session = FocusAnchorSession.getInstance();
      session.companionPaused = snapshot.companionPaused === true;
      session.thoughts = snapshot.thoughts ?? [];
      session.lastText = snapshot.lastText ?? '';
    } catch (_) {
    }
  }

  static async persist(context: common.Context, decision: AgentDecision): Promise<void> {
    const session = FocusAnchorSession.getInstance();
    session.companionPaused = decision.companionPaused;
    session.lastText = decision.userVisibleText;
    const preferencesStore = await preferences.getPreferences(context, PREF_NAME);
    await preferencesStore.put(SESSION_KEY, JSON.stringify({
      companionPaused: session.companionPaused,
      thoughts: session.thoughts,
      lastText: session.lastText
    }));
    await preferencesStore.flush();
  }
}
