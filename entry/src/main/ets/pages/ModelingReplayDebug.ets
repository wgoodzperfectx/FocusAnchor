import { ReplayClient } from '../modeling/ReplayClient';
import { DecisionCandidate, GateContext, evaluateDecision } from '../modeling/DecisionEngine';

/** Isolated debug route. Never calls ReminderService, XiaoyiBridge or Workflow. */
@Entry
@Component
struct ModelingReplayDebug {
  @State baseUrl: string = '';
  @State status: string = 'Synthetic replay only. No live model or Agent connection.';
  private client: ReplayClient = new ReplayClient();

  private async runReplay(): Promise<void> {
    this.status = 'Loading synthetic fixture...';
    const candidate: DecisionCandidate | null = await this.client.nextSyntheticCandidate(this.baseUrl);
    const context: GateContext = {
      now_ms: Date.now(),
      allow_proactive_prompt: false,
      do_not_disturb: false,
      user_requested_help: false,
      explicit_consent_this_time: false,
      time_since_last_intervention_sec: null,
      recent_rejections: 0,
      activity: 'unknown',
      signal_quality: 'unknown'
    };
    const gate = evaluateDecision(candidate, context, candidate !== null);
    this.status = `${gate.outcome} / ${gate.reason_codes.join(', ')} / executed=${gate.executed}`;
  }

  build() {
    Column({ space: 16 }) {
      Text('FocusAnchor modeling replay')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('Debug only: synthetic phone context; default-deny G0; no notification or Agent call.')
        .fontSize(14)
      TextInput({ placeholder: 'HTTPS replay service URL', text: this.baseUrl })
        .onChange((value: string) => { this.baseUrl = value; })
      Button('Run synthetic replay')
        .onClick(() => { this.runReplay(); })
      Text(this.status)
        .fontSize(14)
    }
    .padding(24)
    .width('100%')
  }
}
