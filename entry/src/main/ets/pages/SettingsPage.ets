import { AppState } from '../services/AppState';
import { AppSettings } from '../models/AppTypes';
import { UiPreferenceStore } from '../services/UiPreferenceStore';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct SettingsPage {
  private appState: AppState = AppState.getInstance();
  @State userName: string = '';
  @State language: number = 0;
  @State consentFocusSupport: boolean = false;
  @State consentThoughtSandbox: boolean = false;
  @State shareUsage: boolean = false;
  @State analytics: boolean = false;
  @State localOnly: boolean = true;
  @State showMonitorEntry: boolean = true;
  @State advanced: boolean = false;
  @State hrMin: string = '60';
  @State hrMax: string = '120';
  @State pinEnabled: boolean = false;
  @State pinValue: string = '';
  @State saving: boolean = false;
  @State errorText: string = '';

  aboutToAppear(): void {
    this.loadFromState();
    this.loadMonitorEntry();
  }

  private loadFromState(): void {
    const s = this.appState.settings;
    this.userName = s.userName === 'Learner' ? '' : s.userName;
    this.language = s.language ?? 0;
    this.consentFocusSupport = s.privacy.consentFocusSupport === true;
    this.consentThoughtSandbox = s.privacy.consentThoughtSandbox === true;
    this.shareUsage = s.privacy.shareUsageData;
    this.analytics = s.privacy.allowAnalytics;
    this.localOnly = s.privacy.localEncryptionOnly;
    this.hrMin = `${s.hrMin}`;
    this.hrMax = `${s.hrMax}`;
    this.pinEnabled = s.pinEnabled;
  }

  private zh(): boolean { return this.language === 1; }

  private async loadMonitorEntry(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.showMonitorEntry = await UiPreferenceStore.loadMonitorEntry(context);
    } catch (_error) {
      this.errorText = this.zh() ? '界面偏好暂时无法读取。' : 'Could not load display preference.';
    }
  }

  private async saveAll(): Promise<void> {
    if (this.saving) return;
    this.errorText = '';
    const min = Number.parseInt(this.hrMin);
    const max = Number.parseInt(this.hrMax);
    if (!Number.isSafeInteger(min) || !Number.isSafeInteger(max) || min < 30 || max > 220 || min >= max) {
      this.errorText = this.zh() ? '请检查心率区间。' : 'Check the heart-rate range.';
      return;
    }
    if (this.pinEnabled && !this.appState.settings.pinEnabled && !/^\d{4}$/.test(this.pinValue)) {
      this.errorText = this.zh() ? '请输入 4 位 PIN。' : 'Enter a 4-digit PIN.';
      return;
    }
    this.saving = true;
    const previous = this.appState.settings;
    const settings: AppSettings = {
      age: previous.age,
      avatar: previous.avatar,
      avatarUri: previous.avatarUri,
      userName: this.userName.trim() || 'Learner',
      language: this.language,
      hrMin: min,
      hrMax: max,
      pinEnabled: this.pinEnabled,
      pinHash: this.pinEnabled && this.pinValue.length === 4 ? `${this.pinValue.length}_${this.pinValue}` : previous.pinHash,
      privacy: {
        showAgeOnProfile: previous.privacy.showAgeOnProfile,
        workflowConsentVersion: previous.privacy.workflowConsentVersion,
        consentFocusSupport: this.consentFocusSupport,
        consentThoughtSandbox: this.consentThoughtSandbox,
        shareUsageData: this.shareUsage,
        allowAnalytics: this.analytics,
        localEncryptionOnly: this.localOnly
      }
    };
    try {
      await this.appState.updateSettings(settings, this.pinValue || 'focus-anchor-default');
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await UiPreferenceStore.saveMonitorEntry(context, this.showMonitorEntry);
      promptAction.showToast({ message: this.zh() ? '使用偏好已保存' : 'Preferences saved' });
    } catch (_error) {
      this.errorText = this.zh() ? '保存失败，请重试。' : 'Could not save. Please retry.';
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.zh() ? '返回' : 'Back').fontSize(16).fontColor($r('app.color.primary'))
          .height(48).onClick(() => this.getUIContext().getRouter().back())
        Blank()
        Text(this.zh() ? '使用偏好' : 'Preferences')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Blank()
        Blank().width(48)
      }.width('100%').padding({ left: 20, right: 20, top: 6, bottom: 6 })

      Scroll() {
        Column({ space: 20 }) {
          Column({ space: 10 }) {
            this.heading('称呼与语言', 'Name and language')
            this.note('昵称（可选）', 'Nickname (optional)')
            TextInput({ text: this.userName, placeholder: this.zh() ? '怎么称呼你' : 'How should we address you?' })
              .height(48).fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface')).borderRadius(12)
              .onChange((value: string) => this.userName = value)
            Row({ space: 8 }) {
              Button('English').layoutWeight(1).height(44)
                .fontColor(this.language === 0 ? Color.White : $r('app.color.text_primary'))
                .backgroundColor(this.language === 0 ? $r('app.color.primary') : $r('app.color.surface'))
                .onClick(() => this.language = 0)
              Button('中文').layoutWeight(1).height(44)
                .fontColor(this.language === 1 ? Color.White : $r('app.color.text_primary'))
                .backgroundColor(this.language === 1 ? $r('app.color.primary') : $r('app.color.surface'))
                .onClick(() => this.language = 1)
            }.width('100%')
          }.width('100%')

          Column({ space: 10 }) {
            this.heading('引导与提醒', 'Guidance and reminders')
            Text(this.zh() ? '建议语气 · 待接入' : 'Suggestion tone · not connected')
              .fontSize(15).fontColor($r('app.color.text_primary')).width('100%')
            this.note('当前建议还没有可应用的语气偏好接口。', 'Suggestions have no tone preference interface yet.')
            Text(this.zh() ? '提醒频率 · 待接入' : 'Reminder frequency · not connected')
              .fontSize(15).fontColor($r('app.color.text_primary')).width('100%')
            this.note('现有提醒仍可在任务页使用。', 'Existing reminders remain available from Tasks.')
          }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(16)

          Column({ space: 12 }) {
            this.heading('设备与监测', 'Device and monitoring')
            Text(this.zh() ? '手表连接：未知' : 'Watch connection: Unknown')
              .fontSize(15).fontColor($r('app.color.text_primary')).width('100%')
            this.note('尚无可信设备连接回执。', 'No verified device connection receipt is available.')
            Row() {
              Text(this.zh() ? '在首页显示监测入口' : 'Show monitoring entry on Home')
                .fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.showMonitorEntry })
                .onChange((value: boolean) => this.showMonitorEntry = value)
            }.width('100%').height(48)
            this.note('只控制入口显示，不会启动或关闭监测。',
              'This only changes entry visibility; it does not start monitoring.')
          }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(16)

          Column({ space: 12 }) {
            this.heading('闪念与隐私', 'Thoughts and privacy')
            Row() {
              Text(this.zh() ? '允许本地闪念记录' : 'Save thoughts on this device')
                .fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.consentThoughtSandbox })
                .onChange((value: boolean) => this.consentThoughtSandbox = value)
            }.width('100%').height(48)
            Row() {
              Text(this.zh() ? '允许读取本地任务用于专注支持' : 'Allow local tasks for focus support')
                .fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.consentFocusSupport })
                .onChange((value: boolean) => this.consentFocusSupport = value)
            }.width('100%').height(48)
            this.note('关闭专注支持后，任务读取和闪念捕获会停止。',
              'Turning off focus support stops task access and thought capture.')
            Row() {
              Text(this.zh() ? '分享匿名使用数据' : 'Share anonymous usage data')
                .fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.shareUsage })
                .onChange((value: boolean) => this.shareUsage = value)
            }.width('100%').height(48)
            Row() {
              Text(this.zh() ? '允许本地分析' : 'Allow local analytics')
                .fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.analytics })
                .onChange((value: boolean) => this.analytics = value)
            }.width('100%').height(48)
            Row() {
              Text(this.zh() ? '数据仅本地加密存储' : 'Keep data encrypted on this device')
                .fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.localOnly })
                .onChange((value: boolean) => this.localOnly = value)
            }.width('100%').height(48)
            this.note('隐私选项保存在本机，可随时修改；模拟数据会明确标记。',
              'Privacy choices are stored locally; simulated data are clearly labeled.')
          }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(16)

          Column({ space: 10 }) {
            Text(this.zh() ? '现有安全与监测参数' : 'Existing safety and monitoring options')
              .fontSize(15).fontColor($r('app.color.primary')).width('100%').height(44)
              .onClick(() => this.advanced = !this.advanced)
            if (this.advanced) {
              this.note('心率区间（现有本地设置）', 'Heart-rate range (existing local setting)')
              Row({ space: 10 }) {
                TextInput({ text: this.hrMin, placeholder: 'Min' }).type(InputType.Number).layoutWeight(1)
                  .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface'))
                  .onChange((value: string) => this.hrMin = value)
                TextInput({ text: this.hrMax, placeholder: 'Max' }).type(InputType.Number).layoutWeight(1)
                  .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface'))
                  .onChange((value: string) => this.hrMax = value)
              }.width('100%')
              Row() {
                Text(this.zh() ? 'PIN 锁定' : 'PIN lock').layoutWeight(1)
                  .fontSize(15).fontColor($r('app.color.text_primary'))
                Toggle({ type: ToggleType.Switch, isOn: this.pinEnabled })
                  .onChange((value: boolean) => this.pinEnabled = value)
              }.width('100%').height(48)
              if (this.pinEnabled) {
                TextInput({ text: this.pinValue, placeholder: this.zh() ? '新 PIN（4 位）' : 'New 4-digit PIN' })
                  .type(InputType.Number).maxLength(4)
                  .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.surface'))
                  .onChange((value: string) => this.pinValue = value)
              }
            }
          }.width('100%')
          if (this.errorText.length > 0) {
            Text(this.errorText).fontSize(13).fontColor($r('app.color.danger')).width('100%')
          }
          Button(this.zh() ? '保存偏好' : 'Save preferences')
            .width('100%').height(52).backgroundColor($r('app.color.primary'))
            .enabled(!this.saving).onClick(() => { this.saveAll(); })
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor($r('app.color.page_background'))
  }

  @Builder
  private heading(zhText: string, enText: string) {
    Text(this.zh() ? zhText : enText)
      .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%')
  }

  @Builder
  private note(zhText: string, enText: string) {
    Text(this.zh() ? zhText : enText)
      .fontSize(12).fontColor($r('app.color.text_secondary')).width('100%')
  }
}
