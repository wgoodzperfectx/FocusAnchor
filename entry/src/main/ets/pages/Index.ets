import { HomeTab, TasksTab } from './AppTabs';
import { AppState } from '../services/AppState';
import { t } from '../common/LocaleHelper';

@Entry
@Component
struct Index {
  @State refreshToken: number = 0;
  @State currentIndex: number = 0;
  @State lang: number = 0;
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
    this.clockId = setInterval(() => {
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
    if (this.currentIndex === 2) this.currentIndex = 0;
    this.appState.reloadTasksFromDisk().then(() => {
      this.refreshToken++;
    }).catch(() => {
      this.refreshToken++;
    });
  }

  private openFocus(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/FocusPage' }).catch(() => {
    });
  }

  private openSettings(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' }).catch(() => {
    });
  }

  build() {
    Column() {
        Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
          TabContent() {
            HomeTab({ refreshToken: $refreshToken, lang: this.lang,
              onOpenTasks: () => { this.currentIndex = 1; this.refreshToken++; },
              onOpenSettings: () => this.openSettings() })
          }
          .tabBar(this.tabBuilder(this.tx('tab_home'), 0))

          TabContent() {
            TasksTab({ refreshToken: $refreshToken, lang: this.lang })
          }
          .tabBar(this.tabBuilder(this.tx('tab_tasks'), 1))

          TabContent() {
            Column({ space: 16 }) {
              Text(this.lang === 1 ? '闪念沙盒' : 'Flash sandbox')
                .fontSize(24)
                .fontColor($r('app.color.text_primary'))
              Text(this.lang === 1 ? '记录闪念，准备好时再处理。' : 'Keep thoughts here until you are ready.')
                .fontColor($r('app.color.text_secondary'))
              Button(this.lang === 1 ? '打开闪念沙盒' : 'Open flash sandbox')
                .onClick(() => this.openFocus())
            }
            .width('100%')
            .height('100%')
            .padding(24)
            .backgroundColor('#FAF9F4')
          }
          .tabBar(this.tabBuilder(this.tx('btn_focus'), 2))
        }
        .layoutWeight(1)
        .onChange((index: number) => {
          this.currentIndex = index;
          this.syncLangFromState();
          this.refreshToken++;
          if (index === 2) {
            this.openFocus();
          }
        })
        .barBackgroundColor('#FFFFFF')
        .backgroundColor('#FAF9F4')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF9F4')
  }

  @Builder
  tabBuilder(label: string, targetIndex: number) {
    Column({ space: 4 }) {
      Text(`${label}`)
        .fontSize(12)
        .fontColor(this.currentIndex === targetIndex ? '#386A45' : '#66736A')
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
        .opacity(this.lang >= 0 ? 1 : 1)
    }
    .justifyContent(FlexAlign.Center)
    .height(56)
    .width('100%')
  }
}
