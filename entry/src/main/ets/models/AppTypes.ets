export type HeartRateZone = 'low' | 'optimal' | 'high' | 'unknown';

/** Focus quality: green best → red worst (HR 60–120, 4 bands) */
export type FocusLevel = 'green' | 'yellow' | 'orange' | 'red';

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
  /** Effective urgency: 1 high, 2 medium, 3 low (may auto-raise near deadline) */
  priority: number;
  /** Original urgency chosen by user; used to compute deadline escalation */
  basePriority?: number;
  completed: boolean;
  createdAt: number;
  /** Deadline timestamp (ms) */
  dueAt?: number;
  /** Xiaoyi advice text only (no thinking process) */
  insight?: string;
}

/** Raise urgency by one level when within 24h of deadline (1=highest). */
export function effectivePriorityNearDeadline(task: StudyTask, nowMs: number = Date.now()): number {
  const base = task.basePriority ?? task.priority ?? 2;
  const due = task.dueAt;
  if (task.completed || due === undefined) {
    return base;
  }
  const remain = due - nowMs;
  const dayMs = 24 * 60 * 60 * 1000;
  if (remain <= dayMs) {
    return Math.max(1, base - 1);
  }
  return base;
}

export interface HeartRateSnapshot {
  bpm: number;
  timestamp: number;
  zone: HeartRateZone;
  focusLevel: FocusLevel;
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
  hrMax: 120,
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

/** Map BPM to focus level: 60–120 split into 4 bands, low=good high=bad */
export function focusLevelFromBpm(bpm: number): FocusLevel {
  const clamped = Math.max(60, Math.min(120, bpm));
  if (clamped < 75) {
    return 'green';
  }
  if (clamped < 90) {
    return 'yellow';
  }
  if (clamped < 105) {
    return 'orange';
  }
  return 'red';
}

export function focusLevelColor(level: FocusLevel): string {
  if (level === 'green') {
    return '#2BB673';
  }
  if (level === 'yellow') {
    return '#F1C40F';
  }
  if (level === 'orange') {
    return '#E67E22';
  }
  return '#E74C3C';
}

export function focusLevelToZone(level: FocusLevel): HeartRateZone {
  if (level === 'green') {
    return 'optimal';
  }
  if (level === 'yellow') {
    return 'low';
  }
  if (level === 'orange' || level === 'red') {
    return 'high';
  }
  return 'unknown';
}

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
