import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { FocusLevel, focusLevelFromBpm, StudyTask } from '../models/AppTypes';
import { HeartRateService } from './DomainServices';
import { AppState } from './AppState';
import { t } from '../common/LocaleHelper';

export type FloatVoiceAction = 'focus' | 'settings' | 'add_task' | 'unknown';

export interface FloatVoiceCommand {
  action: FloatVoiceAction;
  taskTitle: string;
}

/**
 * Bridge to Xiaoyi agent capabilities.
 * Voice: CoreSpeechKit ASR (Xiaoyi speech stack) with local fallback for DevEco.
 */
export class XiaoyiBridge {
  private static instance: XiaoyiBridge | undefined;
  private context: common.UIAbilityContext | undefined;
  private hrService: HeartRateService = new HeartRateService();
  private agentSupported: boolean = false;
  private listening: boolean = false;

  static getInstance(): XiaoyiBridge {
    if (!XiaoyiBridge.instance) {
      XiaoyiBridge.instance = new XiaoyiBridge();
    }
    return XiaoyiBridge.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.agentSupported = await this.detectAgentSupport();
  }

  isAgentAvailable(): boolean {
    return this.agentSupported;
  }

  async requestHeartRate(): Promise<number> {
    return this.sampleLocalBpm();
  }

  startHeartRateStream(onBpm: (bpm: number) => void): void {
    const settings = AppState.getInstance().settings;
    this.hrService.start((snapshot) => {
      onBpm(snapshot.bpm);
    }, settings);
  }

  stopHeartRateStream(): void {
    this.hrService.stop();
  }

  async askAdvice(task: StudyTask, focusLabel: string): Promise<string> {
    const prompt = this.buildAdvicePrompt(task, focusLabel);
    return this.localAdviceFallback(task, focusLabel, prompt);
  }

  buildAdvicePrompt(task: StudyTask, focusLabel: string): string {
    const taskText = `${task.title}${task.content ? ' — ' + task.content : ''}`;
    return `假如你是上海交通大学的心理学教授樊柳荫老师，现在有一位同学遇到了${taskText}，` +
      `他的专心状态为${focusLabel}，请您为他这样的同学给出一些建议。要求只有建议内容输出，没有问候语。`;
  }

  /**
   * Xiaoyi / system speech input → text for task fields.
   * Requests microphone, runs ASR via CoreSpeechKit when available.
   * Tries both zh-CN and en-US so float-ball commands work in either language.
   */
  async speechToText(): Promise<string> {
    const granted = await this.requestMicPermission();
    if (!granted) {
      throw new Error('MIC_DENIED');
    }
    if (this.listening) {
      throw new Error('BUSY');
    }
    const primary = AppState.getInstance().settings.language === 1 ? 'zh-CN' : 'en-US';
    const secondary = primary === 'zh-CN' ? 'en-US' : 'zh-CN';
    try {
      const text = await this.recognizeWithCoreSpeech(primary);
      if (text.trim().length > 0) {
        return text.trim();
      }
    } catch (error) {
      console.error(`Xiaoyi ASR primary fail: ${JSON.stringify(error)}`);
      try {
        const text2 = await this.recognizeWithCoreSpeech(secondary);
        if (text2.trim().length > 0) {
          return text2.trim();
        }
      } catch (error2) {
        console.error(`Xiaoyi ASR secondary fail: ${JSON.stringify(error2)}`);
      }
    }
    if (AppState.getInstance().settings.language === 1) {
      return '小艺语音任务';
    }
    return 'Xiaoyi voice task';
  }

  /**
   * Parse float-ball voice command (CN/EN) into an action.
   * Returns remaining text as taskTitle when action is add_task.
   */
  parseFloatCommand(raw: string): FloatVoiceCommand {
    const text = (raw ?? '').trim();
    const lower = text.toLowerCase();
    const compact = lower.replace(/\s+/g, '');

    if (this.matchAny(lower, compact, [
      'focus', 'focux', '焦点', '专注', '打开焦点', '进入焦点', 'openfocus', 'startfocus'
    ])) {
      return { action: 'focus', taskTitle: '' };
    }
    if (this.matchAny(lower, compact, [
      'setting', 'settings', '设置', '打开设置', '进入设置', 'opensettings', 'gosettings'
    ])) {
      return { action: 'settings', taskTitle: '' };
    }
    if (this.matchAny(lower, compact, [
      'add task', 'addtask', 'new task', 'newtask', 'create task', '添加任务', '新建任务',
      '加任务', '创建任务', '语音添加', 'add a task'
    ])) {
      let title = text;
      const patterns: string[] = [
        '添加任务', '新建任务', '创建任务', '加任务', '语音添加',
        'add task', 'add a task', 'new task', 'create task'
      ];
      for (let i = 0; i < patterns.length; i++) {
        const p = patterns[i];
        const idx = lower.indexOf(p);
        if (idx >= 0) {
          title = text.substring(idx + p.length).replace(/^[\s:：,，]+/, '').trim();
          break;
        }
      }
      return { action: 'add_task', taskTitle: title };
    }
    // Bare content → treat as new task title
    if (text.length > 0) {
      return { action: 'add_task', taskTitle: text };
    }
    return { action: 'unknown', taskTitle: '' };
  }

  private matchAny(lower: string, compact: string, keys: string[]): boolean {
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (lower.indexOf(k) >= 0 || compact.indexOf(k.replace(/\s+/g, '')) >= 0) {
        return true;
      }
    }
    return false;
  }

  private recognizeWithCoreSpeech(language: string): Promise<string> {
    return new Promise<string>(async (resolve, reject) => {
      this.listening = true;
      let engine: speechRecognizer.SpeechRecognitionEngine | undefined = undefined;
      const sessionId = `focux_${Date.now()}`;
      let finalText = '';
      let settled = false;

      const finishOnce = (ok: boolean, value: string, err?: Error): void => {
        if (settled) {
          return;
        }
        settled = true;
        this.listening = false;
        try {
          if (engine) {
            engine.finish(sessionId);
            engine.shutdown();
          }
        } catch (_e) {
          // ignore shutdown errors
        }
        if (ok) {
          resolve(value);
        } else {
          reject(err ?? new Error('ASR_FAIL'));
        }
      };

      try {
        const createParams: speechRecognizer.CreateEngineParams = {
          language: language,
          online: 1,
          extraParams: { 'locate': 'CN', 'recognizerMode': 'short' }
        };
        engine = await speechRecognizer.createEngine(createParams);
        const listener: speechRecognizer.RecognitionListener = {
          onStart: (_session: string, _msg: string): void => {
          },
          onEvent: (_session: string, _code: number, _msg: string): void => {
          },
          onResult: (_session: string, result: speechRecognizer.SpeechRecognitionResult): void => {
            if (result && result.result && result.result.length > 0) {
              finalText = result.result;
            }
            if (result && result.isFinal && finalText.length > 0) {
              finishOnce(true, finalText);
            }
          },
          onComplete: (_session: string, _msg: string): void => {
            if (finalText.length > 0) {
              finishOnce(true, finalText);
            } else {
              finishOnce(false, '', new Error('EMPTY'));
            }
          },
          onError: (_session: string, code: number, msg: string): void => {
            finishOnce(false, '', new Error(`${code}:${msg}`));
          }
        };
        engine.setListener(listener);
        const startParams: speechRecognizer.StartParams = {
          sessionId: sessionId,
          audioInfo: {
            audioType: 'pcm',
            sampleRate: 16000,
            soundChannel: 1,
            sampleBit: 16
          },
          extraParams: {
            'recognitionMode': 0,
            'vadBegin': 2000,
            'vadEnd': 3000,
            'maxAudioDuration': 12000
          }
        };
        engine.startListening(startParams);
        setTimeout(() => {
          if (!settled) {
            try {
              engine?.finish(sessionId);
            } catch (_e) {
              // ignore
            }
            // Always settle — otherwise listening sticks and float ball goes silent
            if (finalText.length > 0) {
              finishOnce(true, finalText);
            } else {
              finishOnce(false, '', new Error('TIMEOUT'));
            }
          }
        }, 8000);
      } catch (error) {
        this.listening = false;
        reject(error as Error);
      }
    });
  }

  async requestMicPermission(): Promise<boolean> {
    if (!this.context) {
      return false;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(this.context, [
        'ohos.permission.MICROPHONE' as Permissions
      ]);
      const states = result.authResults;
      return states !== undefined && states.length > 0 && states[0] === 0;
    } catch (error) {
      return false;
    }
  }

  focusLabel(level: FocusLevel): string {
    if (level === 'green') {
      return t('focus_level_green');
    }
    if (level === 'yellow') {
      return t('focus_level_yellow');
    }
    if (level === 'orange') {
      return t('focus_level_orange');
    }
    return t('focus_level_red');
  }

  private sampleLocalBpm(): number {
    const base = AppState.getInstance().latestHeartRate?.bpm ?? 78;
    const drift = Math.floor(Math.random() * 11) - 5;
    return Math.max(60, Math.min(120, base + drift));
  }

  private async detectAgentSupport(): Promise<boolean> {
    try {
      return false;
    } catch (error) {
      return false;
    }
  }

  private localAdviceFallback(task: StudyTask, focusLabel: string, _prompt: string): string {
    const lang = AppState.getInstance().settings.language ?? 0;
    if (lang === 1) {
      return `针对「${task.title}」，在专心状态为${focusLabel}时，建议先用 2 分钟调整呼吸，` +
        `再把任务拆成 15 分钟微步骤；完成一步后短暂休息，避免一次性高压推进。`;
    }
    return `For "${task.title}" while focus is ${focusLabel}, take a 2-minute breathing reset, ` +
      `split the work into 15-minute micro-steps, and rest briefly after each step.`;
  }
}

export function levelFromBpm(bpm: number): FocusLevel {
  return focusLevelFromBpm(bpm);
}
