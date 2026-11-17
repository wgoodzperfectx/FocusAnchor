import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/** Round-watch safe insets */
const SAFE: number = 26;

@Entry
@Component
struct FocusPage {
  @State bpm: number = 78;
  @State ringColor: string = '#2BB673';
  @State lang: number = 0;
  @State shrinkProgress: number = 1;
  @State contentOpacity: number = 0;
  @State wavePhase: number = 0;
  @State barWidth: number = 140;
  @State pageW: number = 200;
  @State pageH: number = 200;
  @State showIris: boolean = true;
  private hrTimer: number = -1;
  private animTimer: number = -1;
  private waveTimer: number = -1;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private waveContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.loadLang();
    this.bpm = 72 + Math.floor(Math.random() * 20);
    this.updateRing();
    this.hrTimer = setInterval(() => {
      const drift = Math.floor(Math.random() * 7) - 3;
      this.bpm = Math.max(60, Math.min(120, this.bpm + drift));
      this.updateRing();
    }, 2000);
    this.shrinkProgress = 1;
    this.contentOpacity = 0;
    this.showIris = true;
    setTimeout(() => this.playEntrance(), 50);
  }

  aboutToDisappear(): void {
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.hrTimer !== -1) {
      clearInterval(this.hrTimer);
      this.hrTimer = -1;
    }
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
    if (this.waveTimer !== -1) {
      clearInterval(this.waveTimer);
      this.waveTimer = -1;
    }
  }

  private async loadLang(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const pref = await preferences.getPreferences(context, 'wear_focux');
      const v = await pref.get('language', 0);
      this.lang = typeof v === 'number' && v === 1 ? 1 : 0;
    } catch (_e) {
      this.lang = 0;
    }
  }

  private updateRing(): void {
    if (this.bpm < 75) {
      this.ringColor = '#2BB673';
    } else if (this.bpm < 90) {
      this.ringColor = '#F1C40F';
    } else if (this.bpm < 105) {
      this.ringColor = '#E67E22';
    } else {
      this.ringColor = '#E74C3C';
    }
  }

  private playEntrance(): void {
    this.shrinkProgress = 1;
    this.showIris = true;
    this.contentOpacity = 0;
    const steps = 30;
    let i = 0;
    this.animTimer = setInterval(() => {
      i++;
      this.shrinkProgress = Math.max(0, 1 - i / steps);
      if (i >= steps) {
        if (this.animTimer !== -1) {
          clearInterval(this.animTimer);
          this.animTimer = -1;
        }
        setTimeout(() => {
          this.showIris = false;
          this.getUIContext().animateTo({
            duration: 400,
            curve: Curve.EaseOut,
            onFinish: () => this.startWave()
          }, () => {
            this.contentOpacity = 1;
          });
        }, 180);
      }
    }, 20);
  }

  private startWave(): void {
    this.drawWave();
    this.waveTimer = setInterval(() => {
      this.wavePhase += 0.22;
      this.drawWave();
    }, 33);
  }

  private drawWave(): void {
    const ctx = this.waveContext;
    const w = this.barWidth > 0 ? this.barWidth : 140;
    const h = 28;
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = '#87CEEB';
    ctx.fillRect(0, 0, w, h);
    ctx.beginPath();
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 2;
    const midY = h / 2;
    const amp = h * 0.28;
    const wavelength = Math.max(48, w / 2);
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

  private whiteSize(): number {
    const maxSide = Math.max(this.pageW, this.pageH) * 1.45;
    const minSide = 24;
    return minSide + (maxSide - minSide) * this.shrinkProgress;
  }

  private ringSize(): number {
    return Math.min(110, this.pageSize() * 0.48);
  }

  private pageSize(): number {
    return Math.min(this.pageW, this.pageH);
  }

  private waveBarW(): number {
    return Math.max(100, this.pageSize() * 0.58);
  }

  private exitPage(): void {
    this.clearTimers();
    this.getUIContext().getRouter().back();
  }

  private unit(): string {
    return this.lang === 1 ? '次/分' : 'bpm';
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      Column({ space: 8 }) {
        Text('<')
          .fontSize(16)
          .fontColor(Color.White)
          .width(28)
          .height(28)
          .borderRadius(14)
          .textAlign(TextAlign.Center)
          .backgroundColor('#333333')
          .opacity(this.contentOpacity)
          .onClick(() => this.exitPage())

        Stack() {
          Circle({ width: this.ringSize(), height: this.ringSize() })
            .fill(Color.Transparent)
            .stroke(this.ringColor)
            .strokeWidth(7)
          Column({ space: 2 }) {
            Text(`${this.bpm}`)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text(this.unit())
              .fontSize(10)
              .fontColor('#CCCCCC')
          }
        }
        .opacity(this.contentOpacity)
        .scale({
          x: 0.6 + 0.4 * this.contentOpacity,
          y: 0.6 + 0.4 * this.contentOpacity
        })

        Column() {
          Canvas(this.waveContext)
            .width('100%')
            .height(28)
            .borderRadius(14)
            .clip(true)
            .onReady(() => this.drawWave())
            .onAreaChange((_o: Area, n: Area) => {
              const w = Number(n.width);
              if (!Number.isNaN(w) && w > 0) {
                this.barWidth = w;
                this.drawWave();
              }
            })
        }
        .width(this.waveBarW())
        .height(28)
        .borderRadius(14)
        .clip(true)
        .backgroundColor('#87CEEB')
        .opacity(this.contentOpacity)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding(SAFE)

      if (this.showIris) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
          Circle({ width: this.whiteSize(), height: this.whiteSize() })
            .fill(Color.White)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .borderRadius('50%')
    .clip(true)
    .onAreaChange((_o: Area, area: Area) => {
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
