import { AppSettings, FocusAdvice, HeartRateSnapshot, HeartRateZone, StudyTask } from '../models/AppTypes';
import { methodLabel, t } from '../common/LocaleHelper';

export class HeartRateService {
  private timerId: number = -1;
  private latestBpm: number = 78;

  start(onSample: (snapshot: HeartRateSnapshot) => void, settings: AppSettings): void {
    this.stop();
    this.timerId = setInterval(() => {
      const drift = Math.floor(Math.random() * 11) - 5;
      this.latestBpm = Math.max(52, Math.min(128, this.latestBpm + drift));
      onSample(this.analyse(this.latestBpm, settings));
    }, 3000);
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

  analyse(bpm: number, settings: AppSettings): HeartRateSnapshot {
    const zone = this.resolveZone(bpm, settings);
    let message = t('hr_msg_optimal');
    if (zone === 'low') {
      message = t('hr_msg_low');
    } else if (zone === 'high') {
      message = t('hr_msg_high');
    }
    return {
      bpm,
      timestamp: Date.now(),
      zone,
      message
    };
  }

  shouldAlert(snapshot: HeartRateSnapshot, settings: AppSettings): boolean {
    return snapshot.bpm < settings.hrMin || snapshot.bpm > settings.hrMax;
  }

  private resolveZone(bpm: number, settings: AppSettings): HeartRateZone {
    if (bpm < settings.hrMin) {
      return 'low';
    }
    if (bpm > settings.hrMax) {
      return 'high';
    }
    return 'optimal';
  }
}

export class AdviceService {
  buildAdvice(snapshot: HeartRateSnapshot | undefined, tasks: StudyTask[]): FocusAdvice[] {
    const advice: FocusAdvice[] = [];
    const pending = tasks.filter((task: StudyTask) => !task.completed);
    const completed = tasks.filter((task: StudyTask) => task.completed).length;
    const completionRate = tasks.length === 0 ? 0 : Math.round((completed / tasks.length) * 100);

    if (snapshot?.zone === 'high') {
      advice.push({
        title: t('advice_high_title'),
        detail: t('advice_high_detail'),
        category: 'alert'
      });
    } else if (snapshot?.zone === 'low') {
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
    const zoneScore = snapshot?.zone === 'optimal' ? 70 : snapshot?.zone === 'high' ? 45 : 55;
    const completion = tasks.length === 0 ? 20 :
      Math.round((tasks.filter((task: StudyTask) => task.completed).length / tasks.length) * 30);
    const priorityScore = tasks.some((task: StudyTask) => !task.completed && task.priority === 1) ? 0 : 10;
    return Math.min(100, zoneScore + completion + priorityScore);
  }
}
