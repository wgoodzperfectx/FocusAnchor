export type HeartRateZone = 'low' | 'optimal' | 'high' | 'unknown';

export type StudyMethod = 'reading' | 'practice' | 'review' | 'discussion' | 'other';

/** Language code: 0 = English, 1 = Chinese */
export type AvatarPreset = 'anchor' | 'book' | 'leaf' | 'star' | 'wave' | 'moon';

export const LANG_EN: number = 0;
export const LANG_ZH: number = 1;

export interface StudyTask {
  id: string;
  title: string;
  content: string;
  studyMinutes: number;
  studyMethod: StudyMethod;
  priority: number;
  completed: boolean;
  createdAt: number;
  dueAt?: number;
}

export interface HeartRateSnapshot {
  bpm: number;
  timestamp: number;
  zone: HeartRateZone;
  message: string;
}

export interface PrivacySettings {
  shareUsageData: boolean;
  allowAnalytics: boolean;
  showAgeOnProfile: boolean;
  localEncryptionOnly: boolean;
}

export interface AppSettings {
  hrMin: number;
  hrMax: number;
  pinEnabled: boolean;
  pinHash: string;
  userName: string;
  age: number;
  /** 0 = English, 1 = Chinese */
  language: number;
  avatar: AvatarPreset;
  /** Absolute file URI from album; empty means use emoji preset */
  avatarUri: string;
  privacy: PrivacySettings;
}

export interface FocusAdvice {
  title: string;
  detail: string;
  category: 'method' | 'strategy' | 'tip' | 'alert';
}

export interface AppDataBundle {
  tasks: StudyTask[];
  heartRateHistory: HeartRateSnapshot[];
  settings: AppSettings;
}

export const DEFAULT_PRIVACY: PrivacySettings = {
  shareUsageData: false,
  allowAnalytics: false,
  showAgeOnProfile: false,
  localEncryptionOnly: true
};

export const DEFAULT_SETTINGS: AppSettings = {
  hrMin: 60,
  hrMax: 100,
  pinEnabled: false,
  pinHash: '',
  userName: 'Learner',
  age: 18,
  language: 0,
  avatar: 'anchor',
  avatarUri: '',
  privacy: DEFAULT_PRIVACY
};

export const AVATAR_OPTIONS: AvatarPreset[] = ['anchor', 'book', 'leaf', 'star', 'wave', 'moon'];

export function avatarEmoji(avatar: AvatarPreset): string {
  if (avatar === 'book') {
    return '📘';
  }
  if (avatar === 'leaf') {
    return '🌿';
  }
  if (avatar === 'star') {
    return '⭐';
  }
  if (avatar === 'wave') {
    return '🌊';
  }
  if (avatar === 'moon') {
    return '🌙';
  }
  return '⚓';
}
