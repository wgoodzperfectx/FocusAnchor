import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import {
  AppDataBundle,
  AppSettings,
  DEFAULT_PRIVACY,
  DEFAULT_SETTINGS,
  HeartRateSnapshot,
  StudyTask
} from '../models/AppTypes';

const PREF_NAME: string = 'focux_anchor_store';
const DATA_KEY: string = 'encrypted_payload';
const SETTINGS_KEY: string = 'settings_plain';
const LANG_KEY: string = 'app_language';

export class StorageService {
  private static instance: StorageService | undefined;
  private context: common.UIAbilityContext | undefined;
  private pref: preferences.Preferences | undefined;

  static getInstance(): StorageService {
    if (!StorageService.instance) {
      StorageService.instance = new StorageService();
    }
    return StorageService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.pref = await preferences.getPreferences(context, PREF_NAME);
  }

  async loadBundle(pin: string): Promise<AppDataBundle> {
    const plainSettings = await this.loadSettings();
    if (!this.pref) {
      return { tasks: [], heartRateHistory: [], settings: plainSettings };
    }
    const encrypted = await this.pref.get(DATA_KEY, '') as string;
    const plainRaw = await this.pref.get(SETTINGS_KEY, '') as string;
    if (!encrypted) {
      return { tasks: [], heartRateHistory: [], settings: plainSettings };
    }
    try {
      const plain = await this.decryptPayload(encrypted, pin || 'focus-anchor-default');
      const parsed = JSON.parse(plain) as AppDataBundle;
      // Plain SETTINGS_KEY is source of truth for language/profile (Settings page writes it).
      // Encrypted blob may contain a stale language:0 and must not wipe Chinese.
      const fromEncrypted = parsed.settings ? this.mergeSettings(parsed.settings) : plainSettings;
      const settings = (plainRaw && plainRaw.length > 0)
        ? plainSettings
        : fromEncrypted;
      return {
        tasks: parsed.tasks ?? [],
        heartRateHistory: parsed.heartRateHistory ?? [],
        settings: settings
      };
    } catch (error) {
      return { tasks: [], heartRateHistory: [], settings: plainSettings };
    }
  }

  async saveBundle(bundle: AppDataBundle, pin: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(SETTINGS_KEY, JSON.stringify(bundle.settings));
    await this.pref.put(LANG_KEY, this.normalizeLanguage(bundle.settings.language));
    const payload = JSON.stringify({
      tasks: bundle.tasks,
      heartRateHistory: bundle.heartRateHistory,
      settings: bundle.settings
    });
    const encrypted = await this.encryptPayload(payload, pin || 'focus-anchor-default');
    await this.pref.put(DATA_KEY, encrypted);
    await this.pref.flush();
  }

  async loadSettings(): Promise<AppSettings> {
    if (!this.pref) {
      return this.mergeSettings(DEFAULT_SETTINGS);
    }
    const raw = await this.pref.get(SETTINGS_KEY, '') as string;
    if (!raw) {
      return this.mergeSettings(DEFAULT_SETTINGS);
    }
    try {
      return this.mergeSettings(JSON.parse(raw) as AppSettings);
    } catch (error) {
      return this.mergeSettings(DEFAULT_SETTINGS);
    }
  }

  private mergeSettings(partial: AppSettings): AppSettings {
    const privacy = partial.privacy;
    return {
      hrMin: partial.hrMin ?? DEFAULT_SETTINGS.hrMin,
      hrMax: partial.hrMax ?? DEFAULT_SETTINGS.hrMax,
      pinEnabled: partial.pinEnabled ?? false,
      pinHash: partial.pinHash ?? '',
      userName: partial.userName ?? DEFAULT_SETTINGS.userName,
      age: partial.age ?? DEFAULT_SETTINGS.age,
      language: this.normalizeLanguage(partial.language),
      avatar: partial.avatar ?? DEFAULT_SETTINGS.avatar,
      avatarUri: partial.avatarUri ?? '',
      privacy: {
        shareUsageData: privacy ? privacy.shareUsageData : DEFAULT_PRIVACY.shareUsageData,
        allowAnalytics: privacy ? privacy.allowAnalytics : DEFAULT_PRIVACY.allowAnalytics,
        showAgeOnProfile: privacy ? privacy.showAgeOnProfile : DEFAULT_PRIVACY.showAgeOnProfile,
        localEncryptionOnly: privacy ? privacy.localEncryptionOnly : DEFAULT_PRIVACY.localEncryptionOnly,
        consentFocusSupport: privacy?.consentFocusSupport === true,
        consentThoughtSandbox: privacy?.consentThoughtSandbox === true,
        workflowConsentVersion: Number.isSafeInteger(privacy?.workflowConsentVersion) && (privacy?.workflowConsentVersion ?? 0) > 0 ? privacy!.workflowConsentVersion : 1
      }
    };
  }

  private normalizeLanguage(value: number | string | undefined | null): number {
    if (typeof value === 'number' && !Number.isNaN(value)) {
      return value === 1 ? 1 : 0;
    }
    if (typeof value === 'string') {
      if (value === '1' || value === 'zh' || value === 'zh-CN') {
        return 1;
      }
      const parsed = Number.parseInt(value);
      return parsed === 1 ? 1 : 0;
    }
    return 0;
  }

  async saveSettings(settings: AppSettings): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(SETTINGS_KEY, JSON.stringify(settings));
    await this.pref.put(LANG_KEY, this.normalizeLanguage(settings.language));
    await this.pref.flush();
  }

  async loadLanguage(): Promise<number> {
    if (!this.pref) {
      return 0;
    }
    try {
      const stored = await this.pref.get(LANG_KEY, -1);
      if (typeof stored === 'number' && stored >= 0) {
        return this.normalizeLanguage(stored);
      }
      const settings = await this.loadSettings();
      return this.normalizeLanguage(settings.language);
    } catch (error) {
      return 0;
    }
  }

  private async encryptPayload(plainText: string, pin: string): Promise<string> {
    const symKey = await this.deriveKey(pin);
    const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    const ivBlob: cryptoFramework.DataBlob = { data: this.randomIv16() };
    const ivParams: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: ivBlob
    };
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, ivParams);
    const input: cryptoFramework.DataBlob = { data: new util.TextEncoder().encodeInto(plainText) };
    const encrypted = await cipher.doFinal(input);
    const ivText = this.uint8ArrayToBase64(ivBlob.data);
    const cipherText = this.uint8ArrayToBase64(encrypted.data);
    return JSON.stringify({ iv: ivText, data: cipherText });
  }

  private async decryptPayload(cipherJson: string, pin: string): Promise<string> {
    const parsed = JSON.parse(cipherJson) as Record<string, string>;
    const symKey = await this.deriveKey(pin);
    const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    const ivBlob: cryptoFramework.DataBlob = { data: this.base64ToUint8Array(parsed.iv) };
    const ivParams: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: ivBlob
    };
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, ivParams);
    const input: cryptoFramework.DataBlob = { data: this.base64ToUint8Array(parsed.data) };
    const decrypted = await cipher.doFinal(input);
    return new util.TextDecoder().decodeToString(decrypted.data);
  }

  private async deriveKey(pin: string): Promise<cryptoFramework.SymKey> {
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: new util.TextEncoder().encodeInto(pin) });
    const digest = await md.digest();
    const generator = cryptoFramework.createSymKeyGenerator('AES256');
    return generator.convertKey(digest);
  }

  private randomIv16(): Uint8Array {
    const iv = new Uint8Array(16);
    for (let i = 0; i < iv.length; i++) {
      iv[i] = Math.floor(Math.random() * 256);
    }
    return iv;
  }

  private randomIv(): Uint8Array {
    const iv = new Uint8Array(12);
    for (let i = 0; i < iv.length; i++) {
      iv[i] = Math.floor(Math.random() * 256);
    }
    return iv;
  }

  private uint8ArrayToBase64(bytes: Uint8Array): string {
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(bytes);
  }

  private base64ToUint8Array(text: string): Uint8Array {
    const helper = new util.Base64Helper();
    return helper.decodeSync(text);
  }
}

export function createTaskId(): string {
  return `task_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
}

export function sortTasks(tasks: StudyTask[]): StudyTask[] {
  return [...tasks].sort((left: StudyTask, right: StudyTask) => {
    if (left.completed !== right.completed) {
      return left.completed ? 1 : -1;
    }
    if (left.priority !== right.priority) {
      return left.priority - right.priority;
    }
    const leftTime = left.dueAt ?? left.createdAt;
    const rightTime = right.dueAt ?? right.createdAt;
    return leftTime - rightTime;
  });
}

export function hashPin(pin: string): string {
  let hash = 0;
  for (let i = 0; i < pin.length; i++) {
    hash = ((hash << 5) - hash) + pin.charCodeAt(i);
    hash |= 0;
  }
  return `${hash}`;
}
