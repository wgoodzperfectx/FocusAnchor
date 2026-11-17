import { common, Want, AgentExtensionAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

export default class FocusAnchorAgentExtAbility extends AgentExtensionAbility {
  onCreate(want: Want) {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onConnect(want: Want, proxy: common.AgentHostProxy) {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onConnect');
  }

  onData(proxy: common.AgentHostProxy, data: string) {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onData');
  }

  onDisconnect(want: Want, proxy: common.AgentHostProxy) {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDisconnect');
  }

  onDestroy() {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }
}