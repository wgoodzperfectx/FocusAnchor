import { HomeTab, TasksTab } from './AppTabs';
import { AppState } from '../services/AppState';
import { avatarEmoji } from '../models/AppTypes';
import { ReminderService } from '../services/ReminderService';
import { t } from '../common/LocaleHelper';
import { FloatBall } from '../components/FloatBall';

@Entry
@Component
struct Index {
  @State refreshToken: number = 0;
  @State currentIndex: number = 0;
  @State lang: number = 0;
  @State clockText: string = '00:00:00';
  private appState: AppState = AppState.getInstance();
  private clockId: number = -1;
  private langWatchId: number = -1;

  private tx(key: string): string {
    return t(key, this.lang);
  }

  /** Keep UI language in sync with persisted AppState.settings.language */
  private syncLangFromState(): void {
    const next = this.appState.settings.language ?? 0;
    if (this.lang !== next) {
      this.lang = next;
      this.refreshToken++;
    }
  }

  aboutToAppear(): void {
    this.syncLangFromState();
    this.clockText = ReminderService.getInstance().formatNow();
    this.clockId = setInterval(() => {
      this.clockText = ReminderService.getInstance().formatNow();
      this.syncLangFromState();
    }, 1000);
    let ticks = 0;
    this.langWatchId = setInterval(() => {
      this.syncLangFromState();
      ticks++;
      if (ticks >= 8 && this.langWatchId !== -1) {
        clearInterval(this.langWatchId);
        this.langWatchId = -1;
      }
    }, 150);
  }

  aboutToDisappear(): void {
    if (this.clockId !== -1) {
      clearInterval(this.clockId);
      this.clockId = -1;
    }
    if (this.langWatchId !== -1) {
      clearInterval(this.langWatchId);
      this.langWatchId = -1;
    }
  }

  onPageShow(): void {
    this.syncLangFromState();
    this.refreshToken++;
  }

  private openFocus(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/FocusPage' }).catch(() => {
    });
  }

  private openSettings(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
    });
  }

  private openAddTask(): void {
    this.currentIndex = 1;
    this.refreshToken++;
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Row({ space: 10 }) {
            if ((this.appState.settings.avatarUri ?? '').length > 0) {
              Image(this.appState.settings.avatarUri)
                .width(28)
                .height(28)
                .borderRadius(14)
                .objectFit(ImageFit.Cover)
            } else {
              Text(avatarEmoji(this.appState.settings.avatar ?? 'anchor'))
                .fontSize(22)
            }
            Column({ space: 2 }) {
              Text(this.tx('app_title'))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(`${this.tx('system_time')} ${this.clockText}`)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
          }

          Blank()

          Text('⚙')
            .fontSize(24)
            .fontColor($r('app.color.text_primary'))
            .padding(8)
            .onClick(() => this.openSettings())
        }
        .width('100%')
        .padding({ left: 16, right: 12, top: 10, bottom: 8 })
        .backgroundColor($r('app.color.surface'))

        Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
          TabContent() {
            HomeTab({ refreshToken: $refreshToken, lang: this.lang, clockText: this.clockText })
          }
          .tabBar(this.tabBuilder(this.tx('tab_home'), 0))

          TabContent() {
            TasksTab({ refreshToken: $refreshToken, lang: this.lang })
          }
          .tabBar(this.tabBuilder(this.tx('tab_tasks'), 1))
        }
        .layoutWeight(1)
        .onChange((index: number) => {
          this.currentIndex = index;
          this.syncLangFromState();
          this.refreshToken++;
        })
        .barBackgroundColor($r('app.color.surface'))
        .backgroundColor($r('app.color.page_background'))
      }
      .width('100%')
      .height('100%')

      FloatBall({
        lang: this.lang,
        onGoFocus: () => this.openFocus(),
        onGoSettings: () => this.openSettings(),
        onGoAddTask: () => this.openAddTask()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  tabBuilder(label: string, targetIndex: number) {
    Column({ space: 4 }) {
      Text(`${label}`)
        .fontSize(12)
        .fontColor(this.currentIndex === targetIndex ? Color.White : $r('app.color.text_secondary'))
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
        .opacity(this.lang >= 0 ? 1 : 1)
    }
    .justifyContent(FlexAlign.Center)
    .height(56)
    .width('100%')
  }
}
