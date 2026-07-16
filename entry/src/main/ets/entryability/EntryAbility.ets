import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppState } from '../services/AppState';

const DOMAIN: number = 0xFA01;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppState.getInstance().bootstrap(this.context).then(() => {
      hilog.info(DOMAIN, 'FocusAnchor', 'App state initialised');
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'FocusAnchor', 'Failed to load Index page: %{public}s', JSON.stringify(err));
      }
    });
  }
}
