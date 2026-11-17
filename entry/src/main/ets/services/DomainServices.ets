import {
  AppSettings,
  FocusAdvice,
  FocusLevel,
  focusLevelFromBpm,
  focusLevelToZone,
  HeartRateSnapshot,
  StudyTask
} from '../models/AppTypes';
import { methodLabel, t } from '../common/LocaleHelper';

export class HeartRateService {
  private timerId: number = -1;
  private latestBpm: number = 78;

  start(onSample: (snapshot: HeartRateSnapshot) => void, settings: AppSettings): void {
    this.stop();
    this.timerId = setInterval(() => {
      const drift = Math.floor(Math.random() * 11) - 5;
      this.latestBpm = Math.max(60, Math.min(120, this.latestBpm + drift));
      onSample(this.analyse(this.latestBpm, settings));
    }, 2000);
  }

  stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  manualSample(bpm: number, settings: AppSettings): HeartRateSnapshot {
    this.latestBpm = bpm;
    return this.analyse(bpm, settings);
  }

  analyse(bpm: number, _settings: AppSettings): HeartRateSnapshot {
    const focusLevel: FocusLevel = focusLevelFromBpm(bpm);
    const zone = focusLevelToZone(focusLevel);
    let message = t('hr_msg_optimal');
    if (focusLevel === 'yellow') {
      message = t('hr_msg_yellow');
    } else if (focusLevel === 'orange') {
      message = t('hr_msg_orange');
    } else if (focusLevel === 'red') {
      message = t('hr_msg_high');
    } else if (focusLevel === 'green') {
      message = t('hr_msg_optimal');
    }
    return {
      bpm,
      timestamp: Date.now(),
      zone,
      focusLevel,
      message
    };
  }

  shouldAlert(snapshot: HeartRateSnapshot, settings: AppSettings): boolean {
    return snapshot.bpm < settings.hrMin || snapshot.bpm > settings.hrMax;
  }
}

export class AdviceService {
  buildAdvice(snapshot: HeartRateSnapshot | undefined, tasks: StudyTask[]): FocusAdvice[] {
    const advice: FocusAdvice[] = [];
    const pending = tasks.filter((task: StudyTask) => !task.completed);
    const completed = tasks.filter((task: StudyTask) => task.completed).length;
    const completionRate = tasks.length === 0 ? 0 : Math.round((completed / tasks.length) * 100);

    if (snapshot?.focusLevel === 'red' || snapshot?.focusLevel === 'orange') {
      advice.push({
        title: t('advice_high_title'),
        detail: t('advice_high_detail'),
        category: 'alert'
      });
    } else if (snapshot?.focusLevel === 'yellow') {
      advice.push({
        title: t('advice_low_title'),
        detail: t('advice_low_detail'),
        category: 'tip'
      });
    } else {
      advice.push({
        title: t('advice_ok_title'),
        detail: t('advice_ok_detail'),
        category: 'strategy'
      });
    }

    if (pending.length > 0) {
      const topTask = [...pending].sort((a, b) => a.priority - b.priority)[0];
      advice.push({
        title: t('advice_next_title'),
        detail: `${topTask.title} · ${topTask.studyMinutes} ${t('min_unit')} · ${methodLabel(topTask.studyMethod)}`,
        category: 'method'
      });
    } else {
      advice.push({
        title: t('advice_empty_title'),
        detail: t('advice_empty_detail'),
        category: 'tip'
      });
    }

    advice.push({
      title: t('advice_rate_title'),
      detail: `${t('advice_rate_detail_prefix')}${completionRate}${t('advice_rate_detail_suffix')}`,
      category: 'strategy'
    });
    return advice;
  }

  efficiencyScore(snapshot: HeartRateSnapshot | undefined, tasks: StudyTask[]): number {
    const level = snapshot?.focusLevel;
    const zoneScore = level === 'green' ? 70 : level === 'yellow' ? 60 : level === 'orange' ? 45 : 35;
    const completion = tasks.length === 0 ? 20 :
      Math.round((tasks.filter((task: StudyTask) => task.completed).length / tasks.length) * 30);
    const priorityScore = tasks.some((task: StudyTask) => !task.completed && task.priority === 1) ? 0 : 10;
    return Math.min(100, zoneScore + completion + priorityScore);
  }
}
