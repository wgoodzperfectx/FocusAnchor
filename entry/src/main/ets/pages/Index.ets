import { HomeTab, HeartTab, TasksTab, InsightsTab } from './AppTabs';
import { AppState } from '../services/AppState';
import { avatarEmoji } from '../models/AppTypes';
import { t } from '../common/LocaleHelper';

@Entry
@Component
struct Index {
  @State refreshToken: number = 0;
  @State currentIndex: number = 0;
  @State lang: number = 0;
  private appState: AppState = AppState.getInstance();

  private tx(key: string): string {
    return this.lang >= 0 ? t(key) : t(key);
  }

  aboutToAppear(): void {
    this.lang = this.appState.settings.language ?? 0;
  }

  onPageShow(): void {
    this.lang = this.appState.settings.language ?? 0;
    this.refreshToken++;
  }

  build() {
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
            Text(this.appState.settings.userName)
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
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' })
              .catch(() => {
              });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 12, top: 10, bottom: 8 })
      .backgroundColor($r('app.color.surface'))

      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          HomeTab({ refreshToken: $refreshToken, lang: this.lang })
        }
        .tabBar(this.tabBuilder(this.tx('tab_home'), 0))

        TabContent() {
          HeartTab({ refreshToken: $refreshToken, lang: this.lang })
        }
        .tabBar(this.tabBuilder(this.tx('tab_heart'), 1))

        TabContent() {
          TasksTab({ refreshToken: $refreshToken, lang: this.lang })
        }
        .tabBar(this.tabBuilder(this.tx('tab_tasks'), 2))

        TabContent() {
          InsightsTab({ refreshToken: $refreshToken, lang: this.lang })
        }
        .tabBar(this.tabBuilder(this.tx('tab_insights'), 3))
      }
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentIndex = index;
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
        .fontColor(this.currentIndex === targetIndex ? $r('app.color.primary') : $r('app.color.text_secondary'))
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
        .opacity(this.lang >= 0 ? 1 : 1)
    }
    .justifyContent(FlexAlign.Center)
    .height(56)
    .width('100%')
  }
}
