import { AppState } from '../services/AppState';
import { XiaoyiBridge } from '../services/XiaoyiBridge';
import { FocusLevel, focusLevelColor, focusLevelFromBpm } from '../models/AppTypes';
import { focusLevelLabel, t } from '../common/LocaleHelper';

@Entry
@Component
struct FocusPage {
  @State bpm: number = 78;
  @State level: FocusLevel = 'green';
  @State ringColor: string = '#2BB673';
  @State lang: number = 0;
  /** 1 → minScale: white disc shrinks toward center ⚪ */
  @State discScale: number = 1;
  @State contentOpacity: number = 0;
  @State wavePhase: number = 0;
  @State barWidth: number = 360;
  @State pageH: number = 800;
  @State pageW: number = 360;
  @State showIris: boolean = true;
  private appState: AppState = AppState.getInstance();
  private bridge: XiaoyiBridge = XiaoyiBridge.getInstance();
  private waveTimer: number = -1;
  private coverTimer: number = -1;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private waveContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private tx(key: string): string {
    return t(key, this.lang);
  }

  aboutToAppear(): void {
    this.lang = this.appState.settings.language ?? 0;
    const current = this.appState.latestHeartRate?.bpm ?? 78;
    this.applyBpm(current);
    this.bridge.startHeartRateStream((bpm: number) => {
      this.applyBpm(bpm);
      this.appState.applyBpm(bpm);
    });
    this.appState.monitoring = true;
    this.discScale = 1;
    this.contentOpacity = 0;
    this.showIris = true;
    setTimeout(() => {
      this.playEntrance();
    }, 60);
  }

  aboutToDisappear(): void {
    this.stopCover();
    this.stopWave();
    this.bridge.stopHeartRateStream();
    this.appState.stopMonitoring();
  }

  private applyBpm(bpm: number): void {
    this.bpm = bpm;
    this.level = focusLevelFromBpm(bpm);
    this.ringColor = focusLevelColor(this.level);
  }

  /** Diameter large enough to cover the whole screen (diagonal). */
  private coverDiameter(): number {
    const w = this.pageW > 0 ? this.pageW : 360;
    const h = this.pageH > 0 ? this.pageH : 800;
    return Math.sqrt(w * w + h * h) * 1.08;
  }

  /** Final size of the center ⚪ before reveal. */
  private endDiameter(): number {
    return 36;
  }

  private minScale(): number {
    return this.endDiameter() / this.coverDiameter();
  }

  private playEntrance(): void {
    this.stopCover();
    this.discScale = 1;
    this.contentOpacity = 0;
    this.showIris = true;
    const steps = 36;
    const target = this.minScale();
    let i = 0;
    this.coverTimer = setInterval(() => {
      i++;
      // Ease-in: shrink faster near the end so the ⚪ is readable
      const t = i / steps;
      const eased = t * t;
      this.discScale = 1 - (1 - target) * eased;
      if (i >= steps) {
        this.discScale = target;
        this.stopCover();
        // Hold the small white circle briefly
        setTimeout(() => {
          this.showIris = false;
          this.getUIContext().animateTo({
            duration: 480,
            curve: Curve.EaseOut,
            onFinish: () => {
              this.startWave();
            }
          }, () => {
            this.contentOpacity = 1;
          });
        }, 220);
      }
    }, 18);
  }

  private stopCover(): void {
    if (this.coverTimer !== -1) {
      clearInterval(this.coverTimer);
      this.coverTimer = -1;
    }
  }

  private startWave(): void {
    this.stopWave();
    this.drawWave();
    this.waveTimer = setInterval(() => {
      this.wavePhase += 0.2;
      this.drawWave();
    }, 33);
  }

  private stopWave(): void {
    if (this.waveTimer !== -1) {
      clearInterval(this.waveTimer);
      this.waveTimer = -1;
    }
  }

  private drawWave(): void {
    const ctx = this.waveContext;
    const w = this.barWidth > 0 ? this.barWidth : this.pageW;
    const h = 56;
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = '#87CEEB';
    ctx.fillRect(0, 0, w, h);
    ctx.beginPath();
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 2.5;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    const midY = h / 2;
    const amp = h * 0.28;
    const wavelength = Math.max(80, w / 2.2);
    for (let x = 0; x <= w; x += 2) {
      const y = midY + amp * Math.sin((x / wavelength) * Math.PI * 2 + this.wavePhase);
      if (x === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();
  }

  private exitPage(): void {
    this.stopCover();
    this.stopWave();
    this.bridge.stopHeartRateStream();
    this.appState.stopMonitoring();
    this.getUIContext().getRouter().back();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      Column() {
        Row() {
          Blank()
          Text('<')
            .fontSize(28)
            .fontColor(Color.White)
            .padding(12)
            .opacity(this.contentOpacity)
            .onClick(() => this.exitPage())
        }
        .width('100%')
        .padding({ top: 12, right: 8 })

        Blank()

        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 220, height: 220 })
            .fill(Color.Transparent)
            .stroke(this.ringColor)
            .strokeWidth(10)
          Column({ space: 8 }) {
            Text(`${this.bpm}`)
              .fontSize(48)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text(this.tx('bpm_unit'))
              .fontSize(14)
              .fontColor('#CCCCCC')
            Text(focusLevelLabel(this.level, this.lang))
              .fontSize(16)
              .fontColor(this.ringColor)
          }
        }
        .opacity(this.contentOpacity)
        .scale({
          x: 0.55 + 0.45 * this.contentOpacity,
          y: 0.55 + 0.45 * this.contentOpacity
        })

        Blank()

        Column() {
          Canvas(this.waveContext)
            .width('100%')
            .height(56)
            .onReady(() => {
              this.drawWave();
            })
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              const w = Number(newValue.width);
              if (!Number.isNaN(w) && w > 0) {
                this.barWidth = w;
                this.drawWave();
              }
            })
        }
        .width('100%')
        .height(56)
        .backgroundColor('#87CEEB')
        .opacity(this.contentOpacity)
        .clip(true)
      }
      .width('100%')
      .height('100%')

      // Entrance: full-screen white disc shrinks to center ⚪
      if (this.showIris) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
          Circle({ width: this.coverDiameter(), height: this.coverDiameter() })
            .fill(Color.White)
            .scale({ x: this.discScale, y: this.discScale })
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((_old: Area, area: Area) => {
      const w = Number(area.width);
      const h = Number(area.height);
      if (!Number.isNaN(w) && w > 0) {
        this.pageW = w;
      }
      if (!Number.isNaN(h) && h > 0) {
        this.pageH = h;
      }
    })
  }
}
