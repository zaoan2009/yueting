import { AppAppearance } from '../model/AppAppearance';
import { ThemeBundles } from '../theme/ThemeBundles';

/** 一个页面只绘制一张装饰底图，内容与滚动容器保持透明。 */
@ComponentV2
export struct ThemeBackgroundComponent {
  /** 兼容旧调用方；银杏/自定义底图不再使用暖色渐变分段。 */
  @Param warmMid: number = 0.35;
  /** 订阅套装与自定义背景变更。 */
  @Local appearance: AppAppearance = AppAppearance.current;

  private themeFillColor(): ResourceStr {
    const custom: string = this.appearance.backgroundColor;
    return custom.length > 0 ? custom : ThemeBundles.background();
  }

  /** 自定义图额外压淡，避免抢正文；银杏资源本身已做成淡彩水印。 */
  private artOpacity(): number {
    return this.appearance.customBackgroundPath.length > 0 ? 0.38 : 1;
  }

  private scrimColor(): ResourceStr {
    const custom: string = this.appearance.backgroundColor;
    if (custom.length > 0) {
      return AppAppearance.withAlpha(custom, 'A8');
    }
    return $r('app.color.theme_ginkgo_bg_scrim');
  }

  build() {
    Stack() {
      if (this.appearance.customBackgroundPath.length > 0) {
        Image(this.appearance.customBackgroundPath)
          .width('100%').height('100%').objectFit(ImageFit.Cover)
          .opacity(this.artOpacity())
          .key(`theme-bg-custom:${this.appearance.customBackgroundName}:${this.appearance.customBackgroundPath}`)
      } else {
        Image(ThemeBundles.backgroundImage())
          .width('100%').height('100%').objectFit(ImageFit.Cover)
          .key(`theme-bg:${ThemeBundles.GinkgoId}`)
      }
      // 轻雾遮罩，保证列表/标题可读，插画只作氛围。
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.scrimColor())
    }.width('100%').height('100%')
      .backgroundColor(this.themeFillColor())
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
        [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }
}
