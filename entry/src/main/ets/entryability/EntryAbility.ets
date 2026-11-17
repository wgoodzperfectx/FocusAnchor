import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppState } from '../services/AppState';

const DOMAIN: number = 0xFA01;

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    // Settings (including language) are loaded in onWindowStageCreate before Index.
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Wait for persisted language before showing UI, otherwise cold start stays English.
    AppState.getInstance().bootstrap(this.context).then(() => {
      hilog.info(DOMAIN, 'FocusAnchor',
        `App state ready, language=${AppState.getInstance().settings.language}`);
      this.loadIndex(windowStage);
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'FocusAnchor', `Bootstrap failed: ${JSON.stringify(err)}`);
      AppState.getInstance().dataError = '本地数据读取失败，请检查存储后重试';
      this.loadIndex(windowStage);
    });
  }

  private loadIndex(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'FocusAnchor', 'Failed to load Index page: %{public}s', JSON.stringify(err));
      }
    });
  }
}
