import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const SAFE: number = 24;

@Entry
@Component
struct SettingsPage {
  @State lang: number = 0;
  @State tick: number = 0;
  private pref: preferences.Preferences | undefined = undefined;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.pref = await preferences.getPreferences(context, 'wear_focux');
      const v = await this.pref.get('language', 0);
      this.lang = typeof v === 'number' && v === 1 ? 1 : 0;
      this.tick++;
    } catch (_e) {
      this.lang = 0;
    }
  }

  private async setLang(v: number): Promise<void> {
    this.lang = v;
    this.tick++;
    if (this.pref) {
      await this.pref.put('language', v);
      await this.pref.flush();
    }
  }

  private label(key: string): string {
    if (this.lang === 1) {
      if (key === 'settings') {
        return '设置';
      }
      if (key === 'language') {
        return '语言';
      }
      if (key === 'en') {
        return 'EN';
      }
      if (key === 'zh') {
        return '中文';
      }
      return key;
    }
    if (key === 'settings') {
      return 'Settings';
    }
    if (key === 'language') {
      return 'Language';
    }
    if (key === 'en') {
      return 'EN';
    }
    if (key === 'zh') {
      return '中文';
    }
    return key;
  }

  build() {
    Column({ space: 8 }) {
      Button('‹')
        .fontSize(20)
        .width(48)
        .height(36)
        .backgroundColor('#36503D')
        .onClick(() => this.getUIContext().getRouter().back())

      Text(`${this.label('settings')}${this.tick >= 0 ? '' : ''}`)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')

      Text(this.label('language'))
        .fontSize(11)
        .fontColor('#B9C8BD')
        .textAlign(TextAlign.Center)
        .width('100%')

      Row({ space: 10 }) {
        Text(this.label('en'))
          .fontSize(12)
          .fontColor(Color.White)
          .width(52)
          .height(42)
          .borderRadius(21)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.lang === 0 ? '#4A7C59' : '#36503D')
          .border({ width: this.lang === 0 ? 1.5 : 0, color: Color.White })
          .onClick(async () => await this.setLang(0))
        Text(this.label('zh'))
          .fontSize(12)
          .fontColor(Color.White)
          .width(52)
          .height(42)
          .borderRadius(21)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.lang === 1 ? '#4A7C59' : '#36503D')
          .border({ width: this.lang === 1 ? 1.5 : 0, color: Color.White })
          .onClick(async () => await this.setLang(1))
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')

      Text(this.lang === 1 ? '设备连接：未知' : 'Device: unknown')
        .fontSize(10)
        .fontColor('#B9C8BD')
        .textAlign(TextAlign.Center)
      Text(this.lang === 1 ? '语音权限：由系统输入法管理，状态未验证' :
        'Voice permission: system keyboard; unverified')
        .fontSize(9)
        .fontColor('#B9C8BD')
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(SAFE)
    .backgroundColor('#202420')
  }
}
