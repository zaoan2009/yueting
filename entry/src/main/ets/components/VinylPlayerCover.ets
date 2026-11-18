import { AppLayout, AppCurve } from '../theme/Theme';
import { PlayerCoverImage } from './PlayerCoverImage';

/**
 * Smartisan ArtisanMusic 唱机：真实黑胶/唱针分层素材。
 * 转盘仅在 playing 时无限旋转；暂停时估算当前角并换新节点，掐断 iterations:-1。
 * 唱臂暂停归位 0°，播放时随进度在外圈→内圈扫动（CustTonearmView：绝对角 103°～120°）。
 */
@ComponentV2
export struct VinylPlayerCover {
  @Param title: string = '';
  @Param author: string = '';
  @Param url: string = '';
  @Param fallback: string = '';
  @Param localPlaceholder: boolean = false;
  @Param highQuality: boolean = false;
  /** 播放中才转盘；暂停停角并抬臂。 */
  @Param playing: boolean = false;
  /** 加载中禁用点按，避免重复起播。 */
  @Param loading: boolean = false;
  /** 0～1 播放进度；决定唱针接触半径（0 外圈，1 近内封）。 */
  @Param progress: number = 0;
  /** 点击唱片切换播放/暂停（有声播放页主入口，底栏不再放播放键）。 */
  @Event onToggle: () => void = () => {};
  /** 当前展示角；播放中为目标角（base+360），暂停为冻结角。 */
  @Local discAngle: number = 0;
  /** 本段旋转起始角（0～360）。 */
  @Local spinBaseAngle: number = 0;
  /** 本段旋转开始时刻；0 表示未在转。 */
  @Local spinStartedAtMs: number = 0;
  /** 变更时重建转盘节点，用于掐断无限旋转动画。 */
  @Local discMountId: number = 0;
  /** 唱臂 rotation（度）；0 = 离碟归位。 */
  @Local armRotation: number = 0;
  /** 落针/抬臂用长动画；进度微调用短时长，避免拖进度时唱针滞后。 */
  @Local armAnimMs: number = 0;

  aboutToAppear(): void {
    this.armAnimMs = 0;
    this.armRotation = this.playing ? this.progressArmRotation() : 0;
    if (this.playing) {
      this.startSpin(this.spinBaseAngle);
    } else {
      this.discAngle = this.spinBaseAngle;
    }
  }

  @Monitor('playing')
  onPlayingChanged(): void {
    if (this.playing) {
      this.startSpin(this.estimateSpinAngle());
      this.armAnimMs = AppLayout.VinylArmDropMs;
      this.armRotation = this.progressArmRotation();
    } else {
      this.freezeSpin();
      this.armAnimMs = AppLayout.VinylArmResetMs;
      this.armRotation = 0;
    }
  }

  @Monitor('progress')
  onProgressChanged(): void {
    if (this.playing) {
      this.armAnimMs = 0;
      this.armRotation = this.progressArmRotation();
    }
  }

  /** 按已运行时长估算当前视觉角，暂停时可对齐停点。 */
  private estimateSpinAngle(): number {
    if (this.spinStartedAtMs <= 0 || AppLayout.VinylSpinMs <= 0) {
      return this.normalizeAngle(this.spinBaseAngle);
    }
    const elapsed: number = Date.now() - this.spinStartedAtMs;
    const turned: number = (elapsed / AppLayout.VinylSpinMs) * 360;
    return this.normalizeAngle(this.spinBaseAngle + turned);
  }

  private normalizeAngle(angle: number): number {
    if (!Number.isFinite(angle)) {
      return 0;
    }
    const mod: number = angle % 360;
    return mod < 0 ? mod + 360 : mod;
  }

  private startSpin(fromAngle: number): void {
    const base: number = this.normalizeAngle(fromAngle);
    this.spinBaseAngle = base;
    this.spinStartedAtMs = Date.now();
    this.discMountId = this.discMountId + 1;
    // 先以静止角挂载，下一帧再推到 base+360，才能触发属性动画的无限循环。
    this.discAngle = base;
    setTimeout((): void => {
      if (!this.playing) {
        return;
      }
      this.spinStartedAtMs = Date.now();
      this.discAngle = base + 360;
    }, 16);
  }

  private freezeSpin(): void {
    const frozen: number = this.estimateSpinAngle();
    this.spinBaseAngle = frozen;
    this.spinStartedAtMs = 0;
    this.discMountId = this.discMountId + 1;
    this.discAngle = frozen;
  }

  private clampedProgress(): number {
    if (!Number.isFinite(this.progress)) {
      return 0;
    }
    if (this.progress <= 0) {
      return 0;
    }
    if (this.progress >= 1) {
      return 1;
    }
    return this.progress;
  }

  /** 播放中唱臂角度：外圈 → 内圈。 */
  private progressArmRotation(): number {
    const t: number = this.clampedProgress();
    return AppLayout.VinylArmOuterDeg +
      (AppLayout.VinylArmInnerDeg - AppLayout.VinylArmOuterDeg) * t;
  }

  @Builder
  private tonearm() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.vinyl_stylus_bg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .hitTestBehavior(HitTestMode.None)

      Image($r('app.media.vinyl_needle_shadow'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .opacity(this.playing ? 0.55 : 0)
        .rotate({ angle: -3, centerX: '69%', centerY: '8%' })
        .animation({
          duration: this.armAnimMs > 0 ? this.armAnimMs : AppLayout.VinylArmResetMs,
          curve: AppCurve.Decelerate
        })
        .hitTestBehavior(HitTestMode.None)

      Image($r('app.media.vinyl_stylus'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .hitTestBehavior(HitTestMode.None)

      Image($r('app.media.vinyl_stylus_top'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .hitTestBehavior(HitTestMode.None)
    }
    .width('14%')
    .aspectRatio(147 / 620)
    .position({ x: '86%', y: '2%' })
    .rotate({
      angle: this.armRotation,
      centerX: '69%',
      centerY: '8%'
    })
    .animation({
      duration: this.armAnimMs,
      curve: AppCurve.Decelerate
    })
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private discFace() {
    Image($r('app.media.vinyl_lp'))
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Contain)
      .hitTestBehavior(HitTestMode.None)

    Image($r('app.media.vinyl_veins'))
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Contain)
      .hitTestBehavior(HitTestMode.None)

    Stack({ alignContent: Alignment.Center }) {
      PlayerCoverImage({
        title: this.title,
        author: this.author,
        url: this.url,
        fallback: this.fallback,
        localPlaceholder: this.localPlaceholder,
        highQuality: this.highQuality,
        radius: 999,
        decorate: false
      })
        .width('100%')
        .height('100%')
        .borderRadius(999)
        .clip(true)

      Column()
        .width('9%')
        .aspectRatio(1)
        .borderRadius(999)
        .backgroundColor('#2A2A2E')
        .border({ width: 1.5, color: '#8A8A92' })
        .shadow({ radius: 3, color: '#66000000', offsetX: 0, offsetY: 1 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(`${Math.round(AppLayout.VinylArtRatio * 100)}%`)
    .aspectRatio(1)
    .borderRadius(999)
    .clip(true)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // playing / 暂停拆成两套节点；discMountId 变化时重建，避免无限旋转停不掉。
      if (this.playing) {
        Stack({ alignContent: Alignment.Center }) {
          this.discFace()
        }
        .width('100%')
        .aspectRatio(1)
        .clip(false)
        .id(`vinyl-spin-${this.discMountId}`)
        .rotate({ angle: this.discAngle })
        .animation({
          duration: AppLayout.VinylSpinMs,
          curve: Curve.Linear,
          iterations: -1,
          expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
        })
      } else {
        Stack({ alignContent: Alignment.Center }) {
          this.discFace()
        }
        .width('100%')
        .aspectRatio(1)
        .clip(false)
        .id(`vinyl-freeze-${this.discMountId}`)
        .rotate({ angle: this.discAngle })
      }

      this.tonearm()
    }
    .width('100%')
    .aspectRatio(1)
    .clip(false)
    .opacity(this.loading ? 0.72 : 1)
    .enabled(!this.loading)
    .id('player-play-toggle')
    .accessibilityText(this.playing || this.loading
      ? $r('app.string.tts_pause') : $r('app.string.tts_play'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .onClick((): void => {
      if (!this.loading) {
        this.onToggle();
      }
    })
  }
}
