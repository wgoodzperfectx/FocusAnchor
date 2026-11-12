import { wearVisualResource } from '../services/WearVisualService';

/** One formal character renderer shared by Action, capture and monitoring pages. */
@Component
export struct WearCompanion {
  @Prop @Watch('onVisualChanged') visualId: string = 'status_ready';
  @Prop widthValue: number = 112;
  @Prop heightValue: number = 88;
  @Prop reducedMotion: boolean = false;
  @State private opacityValue: number = 1;
  @State private scaleValue: number = 1;

  private onVisualChanged(): void {
    if (this.reducedMotion) {
      this.opacityValue = 1;
      this.scaleValue = 1;
      return;
    }
    this.opacityValue = 0.76;
    this.scaleValue = 0.98;
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.opacityValue = 1;
      this.scaleValue = 1;
    });
  }

  build() {
    Stack() {
      Image(wearVisualResource(this.visualId))
        .width(this.widthValue * 0.94)
        .height(this.heightValue * 0.94)
        .objectFit(ImageFit.Contain)
        .opacity(this.opacityValue)
        .scale({ x: this.scaleValue, y: this.scaleValue })
    }
    .width(this.widthValue)
    .height(this.heightValue)
    .backgroundColor($r('app.color.role_stage'))
    .borderRadius(this.heightValue / 2)
  }
}
