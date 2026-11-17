import { HomeTab, TasksTab } from './AppTabs';
import { AppState } from '../services/AppState';
import { t } from '../common/LocaleHelper';
import { FocusContent } from './FocusPage';

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
    this.appState.reloadTasksFromDisk().then(() => {
      this.refreshToken++;
    }).catch(() => {
      this.refreshToken++;
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
            FocusContent({ embedded: true, refreshToken: this.refreshToken })
          }
          .tabBar(this.tabBuilder(this.tx('btn_focus'), 2))
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
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  tabBuilder(label: string, targetIndex: number) {
    Column({ space: 4 }) {
      Text(`${label}`)
        .fontSize(12)
        .fontColor(this.currentIndex === targetIndex ? $r('app.color.primary') : '#66736A')
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
        .opacity(this.lang >= 0 ? 1 : 1)
    }
    .justifyContent(FlexAlign.Center)
    .height(56)
    .width('100%')
  }
}
