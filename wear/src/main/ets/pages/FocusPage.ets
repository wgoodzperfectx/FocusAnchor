import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { WearMonitorSnapshot, WearMonitorState, monitorSourceLabel, monitorStateLabel, monitorVisualId,
  resolveMonitorSnapshot } from '../services/WearUiState';
import { wearVisualResource } from '../services/WearVisualService';

/** Display-only monitor consumer. A device producer has not supplied a trusted snapshot yet. */
@Entry
@Component
struct FocusPage {
  @State lang: number = 0;
  @State monitorState: WearMonitorState = 'UNKNOWN';
  @State dataSource: 'REAL' | 'SIMULATED' | 'UNAVAILABLE' = 'UNAVAILABLE';

  aboutToAppear(): void {
    this.loadLang();
    const params = this.getUIContext().getRouter().getParams() as WearMonitorSnapshot;
    const resolved = resolveMonitorSnapshot(params, Date.now());
    this.monitorState = resolved.state;
    this.dataSource = resolved.source;
  }

  onPageShow(): void {
    this.loadLang();
  }

  private async loadLang(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const pref = await preferences.getPreferences(context, 'wear_focux');
      const value = await pref.get('language', 0);
      this.lang = value === 1 ? 1 : 0;
    } catch (_e) {
      this.lang = 0;
    }
  }

  build() {
    Column({ space: 8 }) {
      Button('‹')
        .width(48)
        .height(36)
        .fontSize(20)
        .backgroundColor('#36503D')
        .onClick(() => this.getUIContext().getRouter().back())
      Text(this.lang === 1 ? '心率监测' : 'Heart rate')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#B9C8BD')
      Image(wearVisualResource(monitorVisualId(this.monitorState)))
        .width(120)
        .height(74)
        .backgroundColor('#F3F5F0')
        .borderRadius(16)
        .objectFit(ImageFit.Contain)
      Text(monitorStateLabel(this.monitorState, this.lang === 1))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .maxLines(2)
        .textAlign(TextAlign.Center)
      Text(monitorSourceLabel(this.dataSource, this.lang === 1))
        .fontSize(8)
        .fontColor('#B9C8BD')
        .width('68%')
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(20)
    .backgroundColor('#202420')
  }
}
