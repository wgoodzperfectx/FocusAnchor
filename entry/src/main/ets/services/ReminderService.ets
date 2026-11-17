import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { StudyTask } from '../models/AppTypes';
import { t } from '../common/LocaleHelper';

export class ReminderService {
  private static instance: ReminderService | undefined;
  private timerId: number = -1;

  static getInstance(): ReminderService {
    if (!ReminderService.instance) {
      ReminderService.instance = new ReminderService();
    }
    return ReminderService.instance;
  }

  formatNow(): string {
    const now = new Date();
    const hh = now.getHours().toString().padStart(2, '0');
    const mm = now.getMinutes().toString().padStart(2, '0');
    const ss = now.getSeconds().toString().padStart(2, '0');
    return `${hh}:${mm}:${ss}`;
  }

  startPeriodicCheck(getTasks: () => StudyTask[]): void {
    this.stop();
    this.timerId = setInterval(() => {
      const pending = getTasks().filter((task: StudyTask) => !task.completed);
      if (pending.length > 0) {
        this.notifyIncomplete(pending.length);
      }
    }, 15 * 60 * 1000);
  }

  stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  async notifyIncomplete(count: number): Promise<void> {
    const request: notificationManager.NotificationRequest = {
      id: 1601,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: t('reminder_title'),
          text: `${t('reminder_body_prefix')}${count}${t('reminder_body_suffix')}`,
          additionalText: this.formatNow()
        }
      }
    };
    try {
      await notificationManager.publish(request);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`notify failed: ${err.code}`);
    }
  }

  async remindNow(tasks: StudyTask[]): Promise<void> {
    const pending = tasks.filter((task: StudyTask) => !task.completed);
    if (pending.length === 0) {
      return;
    }
    await this.notifyIncomplete(pending.length);
  }
}
