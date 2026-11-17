import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME: string = 'focusanchor_ui_preferences';
const MONITOR_ENTRY_KEY: string = 'show_monitor_entry';

/** UI-only preference; it does not start monitoring or assert device connection. */
export class UiPreferenceStore {
  static async loadMonitorEntry(context: common.UIAbilityContext): Promise<boolean> {
    const store = await preferences.getPreferences(context, PREF_NAME);
    return await store.get(MONITOR_ENTRY_KEY, true) as boolean;
  }

  static async saveMonitorEntry(context: common.UIAbilityContext, visible: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, PREF_NAME);
    await store.put(MONITOR_ENTRY_KEY, visible);
    await store.flush();
  }
}
