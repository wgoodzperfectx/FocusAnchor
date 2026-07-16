import { AppState } from '../services/AppState';
import {
  AppSettings,
  AvatarPreset,
  AVATAR_OPTIONS,
  DEFAULT_PRIVACY,
  LANG_EN,
  LANG_ZH,
  avatarEmoji
} from '../models/AppTypes';
import { t } from '../common/LocaleHelper';
import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct SettingsPage {
  private appState: AppState = AppState.getInstance();
  @State userName: string = 'Learner';
  @State ageText: string = '18';
  @State language: number = 0;
  @State avatar: AvatarPreset = 'anchor';
  @State avatarUri: string = '';
  @State shareUsageData: boolean = false;
  @State allowAnalytics: boolean = false;
  @State showAgeOnProfile: boolean = false;
  @State localEncryptionOnly: boolean = true;
  @State hrMin: string = '60';
  @State hrMax: string = '100';
  @State pinEnabled: boolean = false;
  @State pinValue: string = '';
  @State tick: number = 0;

  aboutToAppear(): void {
    this.loadFromState();
  }

  private tx(key: string): string {
    return this.language >= 0 ? t(key) : t(key);
  }

  private loadFromState(): void {
    const settings = this.appState.settings;
    this.userName = settings.userName;
    this.ageText = `${settings.age ?? 18}`;
    this.language = settings.language ?? 0;
    this.avatar = settings.avatar ?? 'anchor';
    this.avatarUri = settings.avatarUri ?? '';
    const privacy = settings.privacy ?? DEFAULT_PRIVACY;
    this.shareUsageData = privacy.shareUsageData;
    this.allowAnalytics = privacy.allowAnalytics;
    this.showAgeOnProfile = privacy.showAgeOnProfile;
    this.localEncryptionOnly = privacy.localEncryptionOnly;
    this.hrMin = `${settings.hrMin}`;
    this.hrMax = `${settings.hrMax}`;
    this.pinEnabled = settings.pinEnabled;
  }

  private async pickFromAlbum(): Promise<void> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (!result.photoUris || result.photoUris.length === 0) {
        return;
      }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const destPath = `${context.filesDir}/avatar_profile.jpg`;
      const src = fs.openSync(result.photoUris[0], fs.OpenMode.READ_ONLY);
      const dest = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.copyFileSync(src.fd, dest.fd);
      fs.closeSync(src);
      fs.closeSync(dest);
      this.avatarUri = fileUri.getUriFromPath(destPath);
      this.tick++;
    } catch (error) {
      promptAction.showToast({ message: this.tx('pick_album_fail') });
    }
  }

  private async saveAll(): Promise<void> {
    const age = Number.parseInt(this.ageText);
    const settings: AppSettings = {
      hrMin: Number.parseInt(this.hrMin) || 60,
      hrMax: Number.parseInt(this.hrMax) || 100,
      pinEnabled: this.pinEnabled,
      pinHash: this.appState.settings.pinHash,
      userName: this.userName.trim() || 'Learner',
      age: Number.isNaN(age) ? 18 : Math.max(6, Math.min(100, age)),
      language: this.language,
      avatar: this.avatar,
      avatarUri: this.avatarUri,
      privacy: {
        shareUsageData: this.shareUsageData,
        allowAnalytics: this.allowAnalytics,
        showAgeOnProfile: this.showAgeOnProfile,
        localEncryptionOnly: this.localEncryptionOnly
      }
    };
    if (this.pinEnabled && this.pinValue.length >= 4) {
      settings.pinHash = `${this.pinValue.length}_${this.pinValue}`;
    }
    await this.appState.updateSettings(settings, this.pinValue || 'focus-anchor-default');
    this.tick++;
    promptAction.showToast({ message: this.tx('saved') });
  }

  build() {
    Column() {
      Row() {
        Text(this.tx('btn_back'))
          .fontSize(16)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
        Blank()
        Text(this.tx('settings_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('⚙')
          .fontSize(20)
          .opacity(0.35)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column({ space: 18 }) {
          Text(this.tx('section_language'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .alignSelf(ItemAlign.Start)

          Row({ space: 10 }) {
            Text(this.tx('lang_en'))
              .fontSize(14)
              .fontColor(this.language === LANG_EN ? Color.White : $r('app.color.text_primary'))
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.language === LANG_EN ? $r('app.color.primary') : $r('app.color.surface'))
              .borderRadius(20)
              .onClick(() => {
                this.language = LANG_EN;
                this.appState.settings.language = LANG_EN;
                this.tick++;
              })
            Text(this.tx('lang_zh'))
              .fontSize(14)
              .fontColor(this.language === LANG_ZH ? Color.White : $r('app.color.text_primary'))
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.language === LANG_ZH ? $r('app.color.primary') : $r('app.color.surface'))
              .borderRadius(20)
              .onClick(() => {
                this.language = LANG_ZH;
                this.appState.settings.language = LANG_ZH;
                this.tick++;
              })
          }
          .width('100%')

          Text(this.tx('section_profile'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .alignSelf(ItemAlign.Start)
          Text(this.tx('profile_hint'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .alignSelf(ItemAlign.Start)

          Column({ space: 8 }) {
            if (this.avatarUri.length > 0) {
              Image(this.avatarUri)
                .width(72)
                .height(72)
                .borderRadius(36)
                .objectFit(ImageFit.Cover)
            } else {
              Text(avatarEmoji(this.avatar))
                .fontSize(48)
            }
            Text(this.userName)
              .fontWeight(FontWeight.Medium)
            if (this.showAgeOnProfile) {
              Text(`${this.tx('label_age')}: ${this.ageText}`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)

          Text(this.tx('label_avatar'))
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(AVATAR_OPTIONS, (item: AvatarPreset) => {
              Text(avatarEmoji(item))
                .fontSize(28)
                .padding(10)
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(this.avatar === item && this.avatarUri.length === 0 ?
                  $r('app.color.primary_soft') : $r('app.color.surface'))
                .borderRadius(12)
                .border({
                  width: this.avatar === item && this.avatarUri.length === 0 ? 2 : 0,
                  color: $r('app.color.primary')
                })
                .onClick(() => {
                  this.avatar = item;
                  this.avatarUri = '';
                })
            }, (item: AvatarPreset) => item)
          }
          .width('100%')

          Button(this.tx('btn_pick_album'))
            .width('100%')
            .height(44)
            .backgroundColor($r('app.color.primary_soft'))
            .fontColor($r('app.color.primary'))
            .onClick(async () => {
              await this.pickFromAlbum();
            })

          Text(this.tx('label_name'))
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.userName, placeholder: this.tx('placeholder_name') })
            .onChange((value: string) => this.userName = value)

          Text(this.tx('label_age'))
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.ageText, placeholder: this.tx('placeholder_age') })
            .type(InputType.Number)
            .onChange((value: string) => this.ageText = value)

          Text(this.tx('section_privacy'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .alignSelf(ItemAlign.Start)
          Text(this.tx('privacy_hint'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .alignSelf(ItemAlign.Start)

          Row() {
            Text(this.tx('privacy_share'))
              .fontSize(14)
              .layoutWeight(1)
              .margin({ right: 12 })
            Toggle({ type: ToggleType.Switch, isOn: this.shareUsageData })
              .onChange((value: boolean) => this.shareUsageData = value)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)

          Row() {
            Text(this.tx('privacy_analytics'))
              .fontSize(14)
              .layoutWeight(1)
              .margin({ right: 12 })
            Toggle({ type: ToggleType.Switch, isOn: this.allowAnalytics })
              .onChange((value: boolean) => this.allowAnalytics = value)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)

          Row() {
            Text(this.tx('privacy_show_age'))
              .fontSize(14)
              .layoutWeight(1)
              .margin({ right: 12 })
            Toggle({ type: ToggleType.Switch, isOn: this.showAgeOnProfile })
              .onChange((value: boolean) => this.showAgeOnProfile = value)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)

          Row() {
            Text(this.tx('privacy_local_only'))
              .fontSize(14)
              .layoutWeight(1)
              .margin({ right: 12 })
            Toggle({ type: ToggleType.Switch, isOn: this.localEncryptionOnly })
              .onChange((value: boolean) => this.localEncryptionOnly = value)
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)

          Text(this.tx('section_heart'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .alignSelf(ItemAlign.Start)
          Text(this.tx('label_hr_range'))
            .fontWeight(FontWeight.Medium)
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

          Row() {
            Text(this.tx('label_pin'))
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.pinEnabled })
              .onChange((value: boolean) => this.pinEnabled = value)
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
            .height(48)
            .backgroundColor($r('app.color.primary'))
            .onClick(async () => {
              await this.saveAll();
            })
        }
        .padding(20)
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
