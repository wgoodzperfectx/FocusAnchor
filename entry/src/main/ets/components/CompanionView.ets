import { companionVisualResource } from '../services/CompanionVisualService';

export type CompanionPlacement = 'HOME' | 'TASK' | 'STEP_SESSION' | 'FOCUS' | 'MONITOR_PANEL';
export type CompanionInteraction = 'IDLE' | 'LOADING' | 'STEP' | 'CLARIFY' | 'ERROR' | 'FALLBACK' | 'SAVED' | 'ACTIVE' | 'PAUSED' | 'COMPLETE' | 'FLASH_SAVED';

@Component
export struct CompanionView {
  @Prop placement: CompanionPlacement = 'HOME';
  @Prop interactionState: CompanionInteraction = 'IDLE';
  @Prop message: string = '';
  @Prop compact: boolean = false;

  private asset(): Resource {
    switch (this.interactionState) {
      case 'LOADING': return companionVisualResource('status_breaking_down');
      case 'STEP': return companionVisualResource('status_first_step');
      case 'CLARIFY': return companionVisualResource('status_awaiting_confirmation');
      case 'ERROR': return companionVisualResource('status_ready');
      case 'FALLBACK': return companionVisualResource('status_ready');
      case 'SAVED': return companionVisualResource('status_first_step');
      case 'ACTIVE': return companionVisualResource('status_in_progress');
      case 'PAUSED': return companionVisualResource('status_paused');
      case 'COMPLETE': return companionVisualResource('status_step_complete');
      case 'FLASH_SAVED': return companionVisualResource('status_ready');
      default: return companionVisualResource('status_ready');
    }
  }

  build() {
    Column({ space: this.compact ? 0 : 10 }) {
      Image(this.asset())
        .width(this.compact ? 42 : this.placement === 'HOME' ? '185%' : this.placement === 'STEP_SESSION' ? 320 : 180)
        .height(this.compact ? 42 : this.placement === 'HOME' ? '100%' : this.placement === 'STEP_SESSION' ? 240 : 135)
        .objectFit(ImageFit.Contain)
        .accessibilityText(this.message)
      if (!this.compact && this.placement !== 'HOME' && this.message.length > 0) {
        Text(this.message)
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(this.placement === 'STEP_SESSION' ? 18 : 16)
          .fontColor('#25332C')
          .maxLines(4)
      }
    }
    .width(this.compact ? 42 : '100%')
    .height(this.placement === 'HOME' ? '100%' : 'auto')
    .alignItems(HorizontalAlign.Center)
  }
}
