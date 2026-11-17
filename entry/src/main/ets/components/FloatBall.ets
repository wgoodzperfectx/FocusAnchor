import { promptAction } from '@kit.ArkUI';
import { AppState } from '../services/AppState';
import { XiaoyiBridge } from '../services/XiaoyiBridge';
import { t } from '../common/LocaleHelper';

const BALL: number = 56;
const EDGE: number = 8;
const MENU_W: number = 148;
const MENU_H: number = 168;
const MOVE_THRESHOLD: number = 10;

@Component
export struct FloatBall {
  @Prop lang: number = 0;
  onGoFocus: () => void = () => {
  };
  onGoSettings: () => void = () => {
  };
  onGoAddTask: () => void = () => {
  };
  @State menuOpen: boolean = false;
  @State voiceOpen: boolean = false;
  @State ballX: number = 0;
  @State ballY: number = 200;
  @State pageW: number = 360;
  @State pageH: number = 720;
  @State voiceBusy: boolean = false;
  @State hint: string = '';
  private moved: boolean = false;
  private originX: number = 0;
  private originY: number = 0;
  private positioned: boolean = false;
  private bridge: XiaoyiBridge = XiaoyiBridge.getInstance();
  private appState: AppState = AppState.getInstance();

  private tx(key: string): string {
    return t(key, this.lang);
  }

  private clamp(v: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, v));
  }

  private ballOnLeft(): boolean {
    return this.ballX + BALL / 2 < this.pageW / 2;
  }

  private snapToEdge(): void {
    const maxY = Math.max(EDGE, this.pageH - BALL - 72);
    this.ballY = this.clamp(this.ballY, EDGE + 48, maxY);
    if (this.ballOnLeft()) {
      this.ballX = EDGE;
    } else {
      this.ballX = Math.max(EDGE, this.pageW - BALL - EDGE);
    }
  }

  /**
   * Menu sits just below the ball:
   * - ball on left  → open toward bottom-right of the ball
   * - ball on right → open toward bottom-left of the ball
   */
  private menuX(): number {
    if (this.ballOnLeft()) {
      return this.clamp(this.ballX, EDGE, this.pageW - MENU_W - EDGE);
    }
    return this.clamp(this.ballX + BALL - MENU_W, EDGE, this.pageW - MENU_W - EDGE);
  }

  private menuY(): number {
    const below = this.ballY + BALL + 6;
    if (below + MENU_H < this.pageH - EDGE) {
      return below;
    }
    // Not enough room below → place above the ball
    return this.clamp(this.ballY - MENU_H - 6, EDGE + 40, this.pageH - MENU_H - EDGE);
  }

  private voicePanelY(): number {
    return Math.max(EDGE, this.pageH - 170);
  }

  private toggleMenu(): void {
    this.voiceOpen = false;
    this.menuOpen = !this.menuOpen;
    this.hint = '';
  }

  private closeMenu(): void {
    this.menuOpen = false;
  }

  private closeVoice(): void {
    this.voiceOpen = false;
  }

  private openVoicePanel(): void {
    this.menuOpen = false;
    this.voiceOpen = true;
    this.hint = this.tx('float_listening');
    promptAction.showToast({ message: this.tx('float_listening') });
    // Let bottom sheet paint before starting ASR
    setTimeout(() => {
      this.runVoice();
    }, 80);
  }

  private async runVoice(): Promise<void> {
    if (this.voiceBusy) {
      return;
    }
    this.voiceBusy = true;
    this.voiceOpen = true;
    this.hint = this.tx('float_listening');
    try {
      const text = await this.bridge.speechToText();
      const cmd = this.bridge.parseFloatCommand(text);
      this.hint = text.length > 0 ? text : this.tx('float_voice_unknown');
      if (cmd.action === 'focus') {
        this.closeVoice();
        this.onGoFocus();
      } else if (cmd.action === 'settings') {
        this.closeVoice();
        this.onGoSettings();
      } else if (cmd.action === 'add_task') {
        this.closeVoice();
        if (cmd.taskTitle.length > 0) {
          const task = this.appState.createBlankTask();
          task.title = cmd.taskTitle;
          task.dueAt = undefined;
          await this.appState.addTask(task);
          promptAction.showToast({ message: `${this.tx('float_task_ok')}: ${cmd.taskTitle}` });
          this.onGoAddTask();
        } else {
          this.appState.requestOpenEditor();
          this.onGoAddTask();
        }
      } else {
        promptAction.showToast({ message: this.tx('float_voice_unknown') });
      }
    } catch (_e) {
      this.hint = this.tx('voice_fail');
      promptAction.showToast({ message: this.tx('voice_fail') });
    } finally {
      this.voiceBusy = false;
    }
  }

  build() {
    Stack() {
      if (this.menuOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000055')
          .onClick(() => this.closeMenu())

        Column({ space: 8 }) {
          Text(this.tx('float_menu_title'))
            .fontSize(12)
            .fontColor('#DDDDDD')
            .width('100%')
            .textAlign(TextAlign.Center)

          Button(this.tx('btn_focus'))
            .width('100%')
            .height(36)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#555555')
            .onClick(() => {
              this.closeMenu();
              this.onGoFocus();
            })

          Button(this.tx('settings_title'))
            .width('100%')
            .height(36)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#555555')
            .onClick(() => {
              this.closeMenu();
              this.onGoSettings();
            })

          Button(this.tx('btn_add_task'))
            .width('100%')
            .height(36)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor('#555555')
            .onClick(() => {
              this.closeMenu();
              this.appState.requestOpenEditor();
              this.onGoAddTask();
            })

          Text(this.tx('float_double_hint'))
            .fontSize(10)
            .fontColor('#999999')
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width(MENU_W)
        .padding(10)
        .backgroundColor('#3A3A3A')
        .borderRadius(14)
        .border({ width: 1, color: '#888888' })
        .position({ x: this.menuX(), y: this.menuY() })
      }

      if (this.voiceOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000055')
          .onClick(() => {
            if (!this.voiceBusy) {
              this.closeVoice();
            }
          })

        Column({ space: 10 }) {
          Text(this.tx('float_voice'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .width('100%')
            .textAlign(TextAlign.Center)

          Text(this.voiceBusy ? this.tx('float_listening') :
            (this.hint.length > 0 ? this.hint : this.tx('float_voice_tip')))
            .fontSize(12)
            .fontColor('#CCCCCC')
            .width('100%')
            .textAlign(TextAlign.Center)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 10 }) {
            Button(this.tx('float_voice_retry'))
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor('#4A7C59')
              .enabled(!this.voiceBusy)
              .onClick(async () => await this.runVoice())
            Button(this.tx('btn_cancel'))
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor('#555555')
              .enabled(!this.voiceBusy)
              .onClick(() => this.closeVoice())
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 28 })
        .backgroundColor('#2F2F2F')
        .borderRadius({ topLeft: 18, topRight: 18 })
        .position({ x: 0, y: this.voicePanelY() })
      }

      Column() {
        Text('◉')
          .fontSize(22)
          .fontColor(Color.White)
      }
      .width(BALL)
      .height(BALL)
      .borderRadius(BALL / 2)
      .backgroundColor(this.voiceBusy ? '#4A7C59' : '#555555')
      .border({ width: 1.5, color: Color.White })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .shadow({ radius: 8, color: '#66000000', offsetX: 0, offsetY: 2 })
      .position({ x: this.ballX, y: this.ballY })
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          // Drag (require clearer movement so taps are not eaten)
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: MOVE_THRESHOLD })
            .onActionStart(() => {
              this.moved = false;
              this.originX = this.ballX;
              this.originY = this.ballY;
            })
            .onActionUpdate((e: GestureEvent) => {
              this.moved = true;
              this.menuOpen = false;
              this.voiceOpen = false;
              this.ballX = this.clamp(this.originX + e.offsetX, 0, Math.max(0, this.pageW - BALL));
              this.ballY = this.clamp(this.originY + e.offsetY, 0, Math.max(0, this.pageH - BALL));
            })
            .onActionEnd(() => {
              this.snapToEdge();
              this.moved = false;
            })
            .onActionCancel(() => {
              this.moved = false;
              this.snapToEdge();
            }),
          // Double-tap → voice at bottom
          TapGesture({ count: 2 })
            .onAction(() => {
              this.openVoicePanel();
            }),
          // Single-tap → quick menu near ball
          TapGesture({ count: 1 })
            .onAction(() => {
              this.toggleMenu();
            })
        )
      )
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior((this.menuOpen || this.voiceOpen) ? HitTestMode.Default : HitTestMode.Transparent)
    .onAreaChange((_o: Area, area: Area) => {
      const w = Number(area.width);
      const h = Number(area.height);
      if (!Number.isNaN(w) && w > 0) {
        this.pageW = w;
      }
      if (!Number.isNaN(h) && h > 0) {
        this.pageH = h;
      }
      if (!this.positioned && this.pageW > 0 && this.pageH > 0) {
        this.positioned = true;
        this.ballX = Math.max(EDGE, this.pageW - BALL - EDGE);
        this.ballY = Math.max(EDGE + 80, this.pageH * 0.55);
        this.snapToEdge();
      }
    })
  }
}
