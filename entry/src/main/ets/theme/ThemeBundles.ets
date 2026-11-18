import { AppThemeBundle } from '../model/AppThemeBundle';

/** 仅保留银杏内置默认；旧套装 ID 一律迁到银杏。 */
export class ThemeBundles {
  static readonly GinkgoId: string = 'ginkgo-winter';
  /** 浅底上图标/正文对比合规；旧亮金 #E8B02E 读取时迁移。 */
  static readonly GinkgoAccent: string = '#8B6914';
  static readonly GinkgoAccentLegacy: string = '#E8B02E';
  static readonly GinkgoBackground: string = '#EAF4F0';
  static readonly GinkgoSurface: string = '#FFF8E8';
  static readonly GinkgoText: string = '#3A2E14';

  /** @deprecated 兼容旧引用；恒等于银杏。 */
  static readonly DefaultId: string = ThemeBundles.GinkgoId;
  /** 产品默认套装（新安装 / 无效记录 / 恢复默认）。 */
  static readonly ProductDefaultId: string = ThemeBundles.GinkgoId;

  static list(): AppThemeBundle[] {
    return [ThemeBundles.resolve(ThemeBundles.GinkgoId)];
  }

  static normalizeId(_id: string): string {
    return ThemeBundles.GinkgoId;
  }

  /** 银杏为唯一内置皮肤；自定义色/图叠在其上。 */
  static hasSkin(_id: string = ''): boolean {
    return true;
  }

  static resolve(_id: string = ''): AppThemeBundle {
    return new AppThemeBundle(ThemeBundles.GinkgoId, $r('app.string.theme_bundle_ginkgo_name'),
      $r('app.string.theme_bundle_ginkgo_description'), ThemeBundles.GinkgoAccent, 3);
  }

  static background(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_background');
  }

  static surface(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_surface');
  }

  static textPrimary(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_text_primary');
  }

  static textSecondary(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_text_secondary');
  }

  static textTertiary(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_text_tertiary');
  }

  static divider(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_divider');
  }

  static appDivider(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_divider');
  }

  static shadow(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_shadow');
  }

  static control(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_control');
  }

  static statusScrim(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_status_scrim');
  }

  static floatingMask(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_floating_mask');
  }

  static brand(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_brand');
  }

  static brandHover(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_brand_hover');
  }

  static brandPressed(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_brand_pressed');
  }

  static brandDisabled(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_brand_disabled');
  }

  static brandSoft(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_brand_soft');
  }

  static onBrand(_id: string = ''): Resource {
    return $r('app.color.theme_ginkgo_on_brand');
  }

  static backgroundImage(_id: string = ''): Resource {
    return $r('app.media.theme_ginkgo_background');
  }

  static cover(_id: string = ''): Resource {
    return $r('app.media.theme_ginkgo_cover');
  }

  static localCover(_id: string = ''): Resource {
    return $r('app.media.theme_ginkgo_local_cover');
  }

  static coverText(_id: string, local: boolean): ResourceColor {
    return local ? $r('app.color.theme_ginkgo_local_cover_text') : $r('app.color.theme_ginkgo_cover_text');
  }

  static coverAuthor(_id: string): ResourceColor {
    return $r('app.color.theme_ginkgo_local_cover_author');
  }

  static coverLabel(_id: string): ResourceColor {
    return $r('app.color.theme_ginkgo_cover_label');
  }
}
