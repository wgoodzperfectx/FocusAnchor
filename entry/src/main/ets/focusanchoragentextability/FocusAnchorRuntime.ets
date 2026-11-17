import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PrivacySettings, StudyTask } from '../models/AppTypes';
import { TaskFileService } from '../services/TaskFileService';
import { resolveFocusConsent } from '../services/FocusConsent';
import { FocusRuntime } from './FocusAnchorSession';
import { FocusAnchorStore } from './FocusAnchorStore';

const PREF_NAME = 'focux_anchor_store';
const SETTINGS_KEY = 'settings_plain';

interface StoredSettingsPayload {
  privacy?: PrivacySettings;
}

export async function loadFocusRuntime(context: common.Context): Promise<FocusRuntime> {
  const privacy = await loadPrivacy(context);
  const consent = resolveFocusConsent(privacy);
  if (!consent.consentFocusSupport) {
    return {
      consentFocusSupport: false,
      consentThoughtSandbox: false
    };
  }
  await FocusAnchorStore.hydrate(context);
  const tasks = TaskFileService.getInstance();
  tasks.init(context);
  const activeTask = (await tasks.loadTasks()).find((task: StudyTask) => !task.completed);
  return {
    consentFocusSupport: consent.consentFocusSupport,
    consentThoughtSandbox: consent.consentThoughtSandbox,
    activeTask: activeTask
  };
}

async function loadPrivacy(context: common.Context): Promise<PrivacySettings> {
  const fallback: PrivacySettings = {
    shareUsageData: false,
    allowAnalytics: false,
    showAgeOnProfile: false,
    localEncryptionOnly: true,
    consentFocusSupport: false,
    consentThoughtSandbox: false
  };
  try {
    const preferencesStore = await preferences.getPreferences(context, PREF_NAME);
    const raw = await preferencesStore.get(SETTINGS_KEY, '') as string;
    if (!raw) {
      return fallback;
    }
    const payload: StoredSettingsPayload = JSON.parse(raw) as StoredSettingsPayload;
    return payload.privacy ?? fallback;
  } catch (_) {
    return fallback;
  }
}
