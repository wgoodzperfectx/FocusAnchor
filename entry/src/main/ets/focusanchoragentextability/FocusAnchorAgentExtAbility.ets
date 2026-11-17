import { common, Want, AgentExtensionAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { loadFocusRuntime } from './FocusAnchorRuntime';
import { routeFocusAnchor } from './FocusAnchorRouter';
import { FocusAnchorStore } from './FocusAnchorStore';
import { resolveFocusConsent } from '../services/FocusConsent';

const DOMAIN = 0x0000;
const TAG = 'FocusAnchorAgent';

interface AgentTaskPayload {
  query?: string;
}

interface AgentParamsPayload {
  task?: AgentTaskPayload;
}

interface AgentInboundPayload {
  text?: string;
  query?: string;
  params?: AgentParamsPayload;
}

export default class FocusAnchorAgentExtAbility extends AgentExtensionAbility {
  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'onCreate %{public}s', want.bundleName ?? '');
  }

  onConnect(want: Want, proxy: common.AgentHostProxy): void {
    hilog.info(DOMAIN, TAG, 'onConnect %{public}s', want.abilityName ?? '');
  }

  onData(proxy: common.AgentHostProxy, data: string): void {
    const utterance = extractUserText(data);
    loadFocusRuntime(this.context).then(async (runtime) => {
      const decision = routeFocusAnchor(utterance, runtime);
      // The snapshot also contains historical thoughts; never rewrite it without consent.
      if (resolveFocusConsent(runtime).consentThoughtSandbox) {
        await FocusAnchorStore.persist(this.context, decision);
      }
      proxy.sendData(decision.userVisibleText);
      hilog.info(DOMAIN, TAG, 'handled %{public}s', decision.intent);
    }).catch(() => {
      const decision = routeFocusAnchor(utterance);
      proxy.sendData(decision.userVisibleText);
    });
  }

  onDisconnect(want: Want, proxy: common.AgentHostProxy): void {
    hilog.info(DOMAIN, TAG, 'onDisconnect %{public}s', want.bundleName ?? '');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }
}

function extractUserText(data: string): string {
  const trimmed = data.trim();
  if (!trimmed.startsWith('{')) {
    return trimmed;
  }
  try {
    const payload: AgentInboundPayload = JSON.parse(trimmed) as AgentInboundPayload;
    return payload.params?.task?.query ?? payload.query ?? payload.text ?? trimmed;
  } catch (_) {
    return trimmed;
  }
}
