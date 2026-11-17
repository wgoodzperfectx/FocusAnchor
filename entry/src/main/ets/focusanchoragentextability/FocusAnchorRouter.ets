import { FocusAnchorSession, FocusRuntime, AgentDecision } from './FocusAnchorSession';
import { StudyTask } from '../models/AppTypes';
import { resolveFocusConsent } from '../services/FocusConsent';

const CRISIS_MARKERS = ['伤害自己', '自杀', '不想活', '想死', '结束生命', '伤害别人'];
const MEDICAL_MARKERS = ['吃药', '停药', '调药', '心率', '诊断', '处方'];

/** Deterministic first-step branch of the local focus workflow. User confirms before delivery. */
export function proposeFirstStep(task: StudyTask, consentFocusSupport: boolean): string | undefined {
  if (consentFocusSupport !== true || !task.title.trim() ||
    containsAny(task.title, CRISIS_MARKERS) || containsAny(task.title, MEDICAL_MARKERS)) {
    return undefined;
  }
  const detail = task.content.trim();
  if (detail.length > 0 && detail.length <= 28 &&
    !containsAny(detail, CRISIS_MARKERS) && !containsAny(detail, MEDICAL_MARKERS)) {
    return detail;
  }
  return `打开「${task.title}」，先做 2 分钟`;
}

export function routeFocusAnchor(utterance: string, runtime?: FocusRuntime): AgentDecision {
  const text = utterance.trim();
  const session = FocusAnchorSession.getInstance();
  if (!text) {
    return reply('clarify', '直接说你想先收住的念头，或你想回到的那一步。', false, session.companionPaused);
  }
  if (text === '暂停' || text === '暂停陪伴') {
    return reply('StartFocusCompanion', '陪伴已暂停，不再提醒。想继续时再说下一步。', false, true);
  }
  if (containsAny(text, CRISIS_MARKERS)) {
    return reply('safety', '我先停住任务建议。请联系身边的人，并按所在地寻求紧急帮助。在中国大陆可以拨打 110 或 120。12356 是心理援助热线，不是急救电话。', false, true);
  }
  if (containsAny(text, MEDICAL_MARKERS)) {
    return reply('safety', '用药和心率读数需要由照护人员判断。我不能解释读数，也不能建议开药、停药或调药。', false, session.companionPaused);
  }
  const consent = resolveFocusConsent(runtime);
  if (!consent.consentFocusSupport) {
    return reply('consent', '当前未开启专注支持。你可以在设置里打开，或直接告诉我这一步想做什么。', false, session.companionPaused);
  }
  const activeTask = runtime?.activeTask;
  if (text.includes('刚才') || text.includes('找回') || text.includes('忘了')) {
    const result = activeTask ? `刚才停在「${activeTask.title}」。打开它，只做下一句。` : '我没有可引用的刚才记录。你还记得停在哪一步吗？';
    return reply('ResumeFocusTask', result, false, session.companionPaused);
  }
  if (text.includes('陪我') || text.includes('开启陪伴')) {
    return reply('StartFocusCompanion', activeTask ? `按轻提醒陪伴。先打开「${activeTask.title}」，只做下一句。` : '按轻提醒陪伴。先选一个两分钟内能开始的动作。', false, false);
  }
  const shouldStore = !text.includes('不要保存') && consent.consentThoughtSandbox;
  if (shouldStore) {
    session.addThought(text, activeTask?.title ?? '');
  }
  const nextStep = activeTask ? `回到「${activeTask.title}」，只做：${activeTask.content || '写下下一句'}` : '选一个两分钟内能开始的动作。';
  return reply('CaptureDistractionThought', `${shouldStore ? '这个念头先放在本地，不上传。' : '这个念头不保存。'}${nextStep}`, shouldStore, session.companionPaused);
}

function reply(intent: string, userVisibleText: string, thoughtStored: boolean, companionPaused: boolean): AgentDecision {
  const session = FocusAnchorSession.getInstance();
  session.companionPaused = companionPaused;
  return { intent, userVisibleText, thoughtStored, companionPaused };
}

function containsAny(text: string, markers: string[]): boolean {
  return markers.some((marker: string) => text.includes(marker));
}
