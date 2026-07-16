import { promptAction } from '@kit.ArkUI';
import { AppState } from '../services/AppState';
import { FocusAdvice, HeartRateSnapshot, StudyMethod, StudyTask } from '../models/AppTypes';
import { methodLabel, hrMessageByZone, t, zoneLabel } from '../common/LocaleHelper';

@Component
export struct MetricCard {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop hint: string = '';
  @Prop lang: number = 0;

  build() {
    Column({ space: 6 }) {
      Text(`${this.title}`)
        .fontSize($r('app.float.caption_font'))
        .fontColor($r('app.color.text_secondary'))
      Text(`${this.value}`)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(`${this.hint}`)
        .fontSize($r('app.float.caption_font'))
        .fontColor($r('app.color.text_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
    .width('100%')
    .opacity(this.lang >= 0 ? 1 : 1)
  }
}

@Component
export struct AdviceCard {
  @Prop advice: FocusAdvice = {
    title: '',
    detail: '',
    category: 'tip'
  };
  @Prop lang: number = 0;

  build() {
    Column({ space: 8 }) {
      Text(`${this.advice.title}`)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(`${this.advice.detail}`)
        .fontSize($r('app.float.body_font'))
        .fontColor($r('app.color.text_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.primary_soft'))
    .borderRadius(16)
    .opacity(this.lang >= 0 ? 1 : 1)
  }
}

@Component
export struct HomeTab {
  @Link refreshToken: number;
  @Prop lang: number = 0;
  private appState: AppState = AppState.getInstance();

  private tx(key: string): string {
    return this.lang >= 0 ? t(key) : t(key);
  }

  private focusStatusValue(): string {
    if (!this.appState.latestHeartRate) {
      return this.tx('zone_waiting');
    }
    return this.appState.latestHeartRate.zone === 'optimal' ? this.tx('focus_calm') : this.tx('focus_alert');
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text(this.tx('app_tagline'))
          .fontSize($r('app.float.caption_font'))
          .fontColor($r('app.color.text_secondary'))

        Row({ space: 12 }) {
          MetricCard({
            title: this.tx('metric_heart_rate'),
            value: `${this.appState.latestHeartRate?.bpm ?? '--'} ${this.tx('bpm_unit')}`,
            hint: zoneLabel(this.appState.latestHeartRate?.zone),
            lang: this.lang
          })
            .layoutWeight(1)
          MetricCard({
            title: this.tx('metric_efficiency'),
            value: `${this.appState.getEfficiencyScore()}`,
            hint: this.tx('metric_efficiency_hint'),
            lang: this.lang
          })
            .layoutWeight(1)
        }
        .width('100%')

        MetricCard({
          title: this.tx('metric_focus_status'),
          value: this.focusStatusValue(),
          hint: hrMessageByZone(this.appState.latestHeartRate?.zone),
          lang: this.lang
        })

        Text(this.tx('latest_guidance'))
          .fontSize($r('app.float.title_font'))
          .fontWeight(FontWeight.Bold)
          .alignSelf(ItemAlign.Start)

        ForEach(this.appState.getAdvice().slice(0, 2), (item: FocusAdvice) => {
          AdviceCard({ advice: item, lang: this.lang })
        }, (item: FocusAdvice) => `${item.category}_${item.title}_${this.lang}_${this.refreshToken}`)
      }
      .padding(20)
    }
    .backgroundColor($r('app.color.page_background'))
    .height('100%')
    .onVisibleAreaChange([0.0, 1.0], () => {
      this.refreshToken++;
    })
  }
}

@Component
export struct HeartTab {
  @Link refreshToken: number;
  @Prop lang: number = 0;
  private appState: AppState = AppState.getInstance();
  @State manualBpm: string = '78';

  private tx(key: string): string {
    return this.lang >= 0 ? t(key) : t(key);
  }

  private handleAlert(snapshot: HeartRateSnapshot): void {
    promptAction.showDialog({
      title: this.tx('hr_alert_title'),
      message: `${snapshot.bpm} ${this.tx('bpm_unit')} · ${hrMessageByZone(snapshot.zone)}`,
      buttons: [{ text: this.tx('hr_alert_ok'), color: '#4F6BED' }]
    });
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        MetricCard({
          title: this.tx('current_bpm'),
          value: `${this.appState.latestHeartRate?.bpm ?? '--'}`,
          hint: `${this.tx('target_bpm')} ${this.appState.settings.hrMin}-${this.appState.settings.hrMax} ${this.tx('bpm_unit')}`,
          lang: this.lang
        })

        Button(this.appState.monitoring ? this.tx('btn_stop_monitor') : this.tx('btn_start_monitor'))
          .width('100%')
          .height(48)
          .backgroundColor($r('app.color.primary'))
          .onClick(async () => {
            if (this.appState.monitoring) {
              this.appState.stopMonitoring();
            } else {
              this.appState.startMonitoring((snapshot: HeartRateSnapshot) => this.handleAlert(snapshot));
            }
            this.refreshToken++;
          })

        Row({ space: 12 }) {
          TextInput({ text: this.manualBpm, placeholder: this.tx('manual_bpm') })
            .type(InputType.Number)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.manualBpm = value;
            })
          Button(this.tx('btn_record'))
            .onClick(async () => {
              const bpm = Number.parseInt(this.manualBpm);
              if (!Number.isNaN(bpm)) {
                const snapshot = await this.appState.manualHeartRate(bpm);
                if (this.appState.shouldAlert(snapshot)) {
                  this.handleAlert(snapshot);
                }
              }
              this.refreshToken++;
            })
        }
        .width('100%')

        Text(this.tx('recent_readings'))
          .fontSize($r('app.float.title_font'))
          .fontWeight(FontWeight.Bold)
          .alignSelf(ItemAlign.Start)

        ForEach(this.appState.heartRateHistory.slice().reverse().slice(0, 6),
          (item: HeartRateSnapshot) => {
            Row() {
              Text(`${item.bpm} ${this.tx('bpm_unit')}`)
                .fontWeight(FontWeight.Medium)
              Blank()
              Text(zoneLabel(item.zone))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(12)
          }, (item: HeartRateSnapshot) => `${item.timestamp}_${this.lang}_${this.refreshToken}`)
      }
      .padding(20)
    }
    .backgroundColor($r('app.color.page_background'))
    .height('100%')
  }
}

@Component
export struct TasksTab {
  @Link refreshToken: number;
  @Prop lang: number = 0;
  private appState: AppState = AppState.getInstance();
  @State showEditor: boolean = false;
  @State draftTitle: string = '';
  @State draftContent: string = '';
  @State draftMinutes: string = '25';
  @State draftMethod: string = 'reading';
  @State draftPriority: number = 2;

  private tx(key: string): string {
    return this.lang >= 0 ? t(key) : t(key);
  }

  private async saveTask(): Promise<void> {
    if (!this.draftTitle.trim()) {
      return;
    }
    const task = this.appState.createBlankTask();
    task.title = this.draftTitle.trim();
    task.content = this.draftContent.trim();
    task.studyMinutes = Number.parseInt(this.draftMinutes) || 25;
    task.studyMethod = this.draftMethod as StudyMethod;
    task.priority = this.draftPriority;
    await this.appState.addTask(task);
    this.showEditor = false;
    this.draftTitle = '';
    this.draftContent = '';
    this.refreshToken++;
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.tx('study_tasks'))
          .fontSize($r('app.float.title_font'))
          .fontWeight(FontWeight.Bold)
        Blank()
        Button(this.tx('btn_add_task'))
          .height(36)
          .fontSize(14)
          .onClick(() => {
            this.showEditor = true;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20 })

      if (this.showEditor) {
        Column({ space: 10 }) {
          TextInput({ text: this.draftTitle, placeholder: this.tx('task_title') })
            .onChange((value: string) => this.draftTitle = value)
          TextArea({ text: this.draftContent, placeholder: this.tx('learning_content') })
            .height(90)
            .onChange((value: string) => this.draftContent = value)
          TextInput({ text: this.draftMinutes, placeholder: this.tx('minutes') })
            .type(InputType.Number)
            .onChange((value: string) => this.draftMinutes = value)
          Row({ space: 8 }) {
            Button(this.tx('priority_high'))
              .backgroundColor(this.draftPriority === 1 ? $r('app.color.primary') : $r('app.color.surface'))
              .fontColor(this.draftPriority === 1 ? Color.White : $r('app.color.text_primary'))
              .onClick(() => this.draftPriority = 1)
            Button(this.tx('priority_medium'))
              .backgroundColor(this.draftPriority === 2 ? $r('app.color.primary') : $r('app.color.surface'))
              .fontColor(this.draftPriority === 2 ? Color.White : $r('app.color.text_primary'))
              .onClick(() => this.draftPriority = 2)
            Button(this.tx('priority_low'))
              .backgroundColor(this.draftPriority === 3 ? $r('app.color.primary') : $r('app.color.surface'))
              .fontColor(this.draftPriority === 3 ? Color.White : $r('app.color.text_primary'))
              .onClick(() => this.draftPriority = 3)
          }
          Row({ space: 12 }) {
            Button(this.tx('btn_save'))
              .layoutWeight(1)
              .onClick(async () => await this.saveTask())
            Button(this.tx('btn_cancel'))
              .layoutWeight(1)
              .backgroundColor($r('app.color.surface'))
              .fontColor($r('app.color.text_primary'))
              .onClick(() => this.showEditor = false)
          }
        }
        .padding({ left: 20, right: 20 })
      }

      List({ space: 10 }) {
        ForEach(this.appState.tasks, (task: StudyTask) => {
          ListItem() {
            Column({ space: 6 }) {
              Row() {
                Text(task.title)
                  .fontWeight(FontWeight.Medium)
                  .decoration({ type: task.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
                Blank()
                Text(`P${task.priority}`)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              Text(`${task.studyMinutes} ${this.tx('min_unit')} · ${methodLabel(task.studyMethod)}`)
                .fontSize($r('app.float.caption_font'))
                .fontColor($r('app.color.text_secondary'))
              Row({ space: 8 }) {
                Button(task.completed ? this.tx('btn_undo') : this.tx('btn_done'))
                  .height(32)
                  .onClick(async () => {
                    await this.appState.toggleTask(task.id);
                    this.refreshToken++;
                  })
                Button(this.tx('btn_remove'))
                  .height(32)
                  .backgroundColor($r('app.color.danger'))
                  .onClick(async () => {
                    await this.appState.removeTask(task.id);
                    this.refreshToken++;
                  })
              }
            }
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(14)
          }
        }, (task: StudyTask) => `${task.id}_${this.lang}_${this.refreshToken}`)
      }
      .layoutWeight(1)
      .padding({ left: 20, right: 20, bottom: 20 })
    }
    .backgroundColor($r('app.color.page_background'))
    .height('100%')
  }
}

@Component
export struct InsightsTab {
  @Link refreshToken: number;
  @Prop lang: number = 0;
  private appState: AppState = AppState.getInstance();

  private tx(key: string): string {
    return this.lang >= 0 ? t(key) : t(key);
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        MetricCard({
          title: this.tx('efficiency_index'),
          value: `${this.appState.getEfficiencyScore()}/100`,
          hint: this.tx('efficiency_hint'),
          lang: this.lang
        })

        Text(this.tx('personal_suggestions'))
          .fontSize($r('app.float.title_font'))
          .fontWeight(FontWeight.Bold)
          .alignSelf(ItemAlign.Start)

        ForEach(this.appState.getAdvice(), (item: FocusAdvice) => {
          AdviceCard({ advice: item, lang: this.lang })
        }, (item: FocusAdvice) => `${item.category}_${item.title}_${this.lang}_${this.refreshToken}`)
      }
      .padding(20)
    }
    .backgroundColor($r('app.color.page_background'))
    .height('100%')
  }
}

@Component
export struct SettingsTab {
  @Link refreshToken: number;
  @Prop lang: number = 0;
  private appState: AppState = AppState.getInstance();
  @State hrMin: string = '60';
  @State hrMax: string = '100';
  @State userName: string = 'Learner';
  @State pinEnabled: boolean = false;
  @State pinValue: string = '';

  private tx(key: string): string {
    return this.lang >= 0 ? t(key) : t(key);
  }

  aboutToAppear(): void {
    this.hrMin = `${this.appState.settings.hrMin}`;
    this.hrMax = `${this.appState.settings.hrMax}`;
    this.userName = this.appState.settings.userName;
    this.pinEnabled = this.appState.settings.pinEnabled;
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text(this.tx('label_hr_range'))
          .fontSize($r('app.float.title_font'))
          .fontWeight(FontWeight.Bold)
          .alignSelf(ItemAlign.Start)
        Row({ space: 12 }) {
          TextInput({ text: this.hrMin, placeholder: this.tx('placeholder_hr_min') })
            .type(InputType.Number)
            .layoutWeight(1)
            .onChange((value: string) => this.hrMin = value)
          TextInput({ text: this.hrMax, placeholder: this.tx('placeholder_hr_max') })
            .type(InputType.Number)
            .layoutWeight(1)
            .onChange((value: string) => this.hrMax = value)
        }
        .width('100%')

        TextInput({ text: this.userName, placeholder: this.tx('placeholder_name') })
          .onChange((value: string) => this.userName = value)

        Row() {
          Text(this.tx('label_pin'))
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.pinEnabled })
            .onChange((isOn: boolean) => this.pinEnabled = isOn)
        }
        .width('100%')

        if (this.pinEnabled) {
          TextInput({ text: this.pinValue, placeholder: this.tx('placeholder_pin') })
            .type(InputType.Number)
            .maxLength(4)
            .onChange((value: string) => this.pinValue = value)
        }

        Button(this.tx('btn_save'))
          .width('100%')
          .backgroundColor($r('app.color.primary'))
          .onClick(async () => {
            const settings = this.appState.settings;
            settings.hrMin = Number.parseInt(this.hrMin) || 60;
            settings.hrMax = Number.parseInt(this.hrMax) || 100;
            settings.userName = this.userName.trim() || 'Learner';
            settings.pinEnabled = this.pinEnabled;
            if (this.pinEnabled && this.pinValue.length >= 4) {
              settings.pinHash = `${this.pinValue.length}_${this.pinValue}`;
            }
            await this.appState.updateSettings(settings, this.pinValue || 'focus-anchor-default');
            promptAction.showToast({ message: this.tx('saved') });
            this.refreshToken++;
          })
      }
      .padding(20)
    }
    .backgroundColor($r('app.color.page_background'))
    .height('100%')
  }
}
