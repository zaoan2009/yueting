import { curves } from '@kit.ArkUI';
import lazy { uiMaterial } from '@kit.ArkUI';
import { AppAppearance } from '../model/AppAppearance';
import { PlatformCompat } from '../utils/PlatformCompat';
import { ThemeBundles } from './ThemeBundles';

/** App 外观语义入口；深浅色由同名 base/dark 资源解析，阅读正文继续使用 ReaderTheme。 */
export class AppTheme {
  static get bundleId(): string {
    return ThemeBundles.normalizeId(AppAppearance.current.themeBundleId);
  }
  /** 银杏皮肤始终启用；自定义色/图叠在银杏之上。 */
  static get hasSkin(): boolean {
    return true;
  }
  /** @deprecated 使用 hasSkin。 */
  static get isPaper(): boolean { return AppTheme.hasSkin; }
  static get usesBundleAccent(): boolean {
    const accent: string = AppAppearance.current.accent;
    return accent === ThemeBundles.GinkgoAccent || accent === ThemeBundles.GinkgoAccentLegacy;
  }
  /** @deprecated 使用 usesBundleAccent。 */
  static get usesPaperAccent(): boolean { return AppTheme.usesBundleAccent; }
  static get Background(): ResourceStr {
    const custom: string = AppAppearance.current.backgroundColor;
    return custom.length > 0 ? custom : ThemeBundles.background(AppTheme.bundleId);
  }
  static get Surface(): ResourceStr {
    const custom: string = AppAppearance.current.surfaceColor;
    return custom.length > 0 ? custom : ThemeBundles.surface(AppTheme.bundleId);
  }
  static get TextPrimary(): ResourceStr {
    const custom: string = AppAppearance.current.textColor;
    return custom.length > 0 ? custom : ThemeBundles.textPrimary(AppTheme.bundleId);
  }
  static get TextSecondary(): ResourceStr {
    const custom: string = AppAppearance.current.textColor;
    return custom.length > 0 ? AppAppearance.withAlpha(custom, '99') :
      ThemeBundles.textSecondary(AppTheme.bundleId);
  }
  static get TextTertiary(): ResourceStr {
    const custom: string = AppAppearance.current.textColor;
    return custom.length > 0 ? AppAppearance.withAlpha(custom, '66') :
      ThemeBundles.textTertiary(AppTheme.bundleId);
  }
  static get IconPrimary(): ResourceStr {
    return AppTheme.TextPrimary;
  }
  static get IconSecondary(): ResourceStr {
    return AppTheme.TextSecondary;
  }
  static get Divider(): ResourceStr {
    const custom: string = AppAppearance.current.textColor;
    return custom.length > 0 ? AppAppearance.withAlpha(custom, '33') :
      ThemeBundles.divider(AppTheme.bundleId);
  }
  static get BackgroundImage(): Resource {
    return ThemeBundles.backgroundImage(AppTheme.bundleId);
  }
  static get customBackgroundPath(): string {
    return AppAppearance.current.customBackgroundPath;
  }
}

export class AppColor {
  static get Brand(): ResourceStr {
    if (AppTheme.usesBundleAccent) return ThemeBundles.brand(AppTheme.bundleId);
    const accent: string = AppAppearance.current.accent;
    return accent.length > 0 ? accent : $r('app.color.app_brand');
  }
  static get BrandHover(): ResourceStr {
    if (AppTheme.usesBundleAccent) return ThemeBundles.brandHover(AppTheme.bundleId);
    const accent: string = AppAppearance.current.accent;
    return accent.length > 0 ? AppAppearance.shade(accent, 0.92) : $r('app.color.app_brand_hover');
  }
  static get BrandPressed(): ResourceStr {
    if (AppTheme.usesBundleAccent) return ThemeBundles.brandPressed(AppTheme.bundleId);
    const accent: string = AppAppearance.current.accent;
    return accent.length > 0 ? AppAppearance.shade(accent, 0.82) : $r('app.color.app_brand_pressed');
  }
  static get BrandDisabled(): ResourceStr {
    if (AppTheme.usesBundleAccent) return ThemeBundles.brandDisabled(AppTheme.bundleId);
    const accent: string = AppAppearance.current.accent;
    return accent.length > 0 ? '#66' + accent.substring(1) : $r('app.color.app_brand_disabled');
  }
  static get BrandSoft(): ResourceStr {
    if (AppTheme.usesBundleAccent) return ThemeBundles.brandSoft(AppTheme.bundleId);
    const accent: string = AppAppearance.current.accent;
    return accent.length > 0 ? '#22' + accent.substring(1) : $r('app.color.app_brand_soft');
  }
  static get BrandDark(): ResourceStr {
    if (AppTheme.usesBundleAccent) return ThemeBundles.brandPressed(AppTheme.bundleId);
    const accent: string = AppAppearance.current.accent;
    return accent.length > 0 ? AppAppearance.shade(accent, 0.78) : $r('app.color.app_brand_dark');
  }
  static get OnBrand(): ResourceStr {
    if (AppTheme.usesBundleAccent) return ThemeBundles.onBrand(AppTheme.bundleId);
    const accent: string = AppAppearance.current.accent;
    return accent.length > 0 ? AppAppearance.foreground(accent) : $r('app.color.app_on_brand');
  }
  static get Divider(): Resource {
    return ThemeBundles.appDivider(AppTheme.bundleId);
  }
  static get Shadow(): Resource {
    return ThemeBundles.shadow(AppTheme.bundleId);
  }
  static get GlassControlFallback(): Resource {
    return AppTheme.hasSkin ? ThemeBundles.control(AppTheme.bundleId) : $r('app.color.glass_control_fallback');
  }
  static readonly GlassSheetFallback: Resource = $r('app.color.glass_sheet_fallback');
  static get GlassControlTint(): Resource {
    return AppTheme.hasSkin ? ThemeBundles.control(AppTheme.bundleId) : $r('app.color.glass_control_tint');
  }
  static readonly GlassSheetControlTint: Resource = $r('app.color.glass_sheet_control_tint');
  static readonly GlassSheetStroke: Resource = $r('app.color.glass_sheet_stroke');
  static readonly GlassTextPrimary: Resource = $r('app.color.glass_text_primary');
  static readonly GlassTextSecondary: Resource = $r('app.color.glass_text_secondary');
  static readonly GlassTextTertiary: Resource = $r('app.color.glass_text_tertiary');
  static readonly GlassDivider: Resource = $r('app.color.glass_divider');
  static get GlassStroke(): Resource {
    return AppTheme.hasSkin ? ThemeBundles.divider(AppTheme.bundleId) : $r('app.color.glass_stroke');
  }
  static readonly GlassShadow: Resource = $r('app.color.glass_shadow');

  // Legacy literal overlays retained for existing call sites.
  static readonly GlassBg: string = '#33FFFFFF';
  static readonly GlassBgDark: string = '#33000000';
}

/** 原生材质统一入口；每次外观变更清空缓存，避免重复创建或保留旧光感色。 */
export class AppMaterial {
  private static cache: Map<string, uiMaterial.Material> = new Map<string, uiMaterial.Material>();
  private static appearanceKey: string = '';

  private static resolveStyle(fallback: uiMaterial.ImmersiveStyle): uiMaterial.ImmersiveStyle {
    switch (AppAppearance.current.material) {
      case 1: return uiMaterial.ImmersiveStyle.ULTRA_THIN;
      case 2: return uiMaterial.ImmersiveStyle.THIN;
      case 3: return uiMaterial.ImmersiveStyle.REGULAR;
      case 4: return uiMaterial.ImmersiveStyle.THICK;
      case 5: return uiMaterial.ImmersiveStyle.ULTRA_THICK;
      default: return fallback;
    }
  }

  private static material(key: string, fallback: uiMaterial.ImmersiveStyle,
    shadow: boolean, interactive: boolean, invert: boolean = false,
    fixedStyle: boolean = false): uiMaterial.Material {
    const appearanceKey: string = AppAppearance.current.themeBundleId + ':' +
      AppAppearance.current.material.toString() + ':' + AppAppearance.current.accent;
    if (appearanceKey !== AppMaterial.appearanceKey) {
      AppMaterial.cache.clear();
      AppMaterial.appearanceKey = appearanceKey;
    }
    // Read the reactive brand token even on a cache hit, so mounted controls observe theme changes.
    const lightColor: ResourceColor = AppColor.Brand;
    const cached: uiMaterial.Material | undefined = AppMaterial.cache.get(key);
    if (cached !== undefined) return cached;
    const material: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
      style: fixedStyle ? fallback : AppMaterial.resolveStyle(fallback),
      applyShadow: shadow,
      interactive: interactive,
      colorInvert: invert,
      lightEffect: { color: lightColor }
    });
    AppMaterial.cache.set(key, material);
    return material;
  }

  static get InteractiveThin(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('interactiveThin', uiMaterial.ImmersiveStyle.THIN, false, true);
  }
  static get InteractiveClean(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('interactiveClean', uiMaterial.ImmersiveStyle.THIN, false, true, true);
  }
  static get SurfaceClean(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('surfaceClean', uiMaterial.ImmersiveStyle.THIN, false, false);
  }
  static get FloatingControl(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('floating', uiMaterial.ImmersiveStyle.ULTRA_THIN, true, true);
  }
  static get Sheet(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('sheet', uiMaterial.ImmersiveStyle.THIN, true, false);
  }
  static get PlayerSheet(): uiMaterial.Material | undefined {
    return AppMaterial.ReaderSheetThick;
  }
  static get PlayerSheetBlur(): BlurStyle | undefined {
    return AppMaterial.ReaderSheetBlur;
  }
  /** 阅读页底部悬浮胶囊栏：固定薄光感材质 + 柔和投影，同官方浮动 Tab 视觉。 */
  static get ReaderBar(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('readerBar', uiMaterial.ImmersiveStyle.THIN, true, false);
  }
  /** 阅读与听书弹层固定弱档（厚材质），不跟随全局材质偏好。 */
  static get ReaderSheetThick(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('readerSheetThick', uiMaterial.ImmersiveStyle.THICK, true, false, false, true);
  }
  static get ReaderSheetBlur(): BlurStyle | undefined {
    return PlatformCompat.immersiveMaterial ? undefined : BlurStyle.COMPONENT_THICK;
  }
  static get DialogUltraThick(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('dialog', uiMaterial.ImmersiveStyle.ULTRA_THICK, true, false);
  }
  static get SurfaceRegular(): uiMaterial.Material | undefined {
    if (!PlatformCompat.immersiveMaterial) return undefined;
    return AppMaterial.material('regular', uiMaterial.ImmersiveStyle.REGULAR, true, false);
  }

  static get SheetBackground(): ResourceColor {
    return PlatformCompat.immersiveMaterial ? Color.Transparent : $r('sys.color.comp_background_primary');
  }

  static get SheetBlur(): BlurStyle | undefined {
    return PlatformCompat.immersiveMaterial ? undefined : AppMaterial.fallbackBlur;
  }

  private static get fallbackBlur(): BlurStyle {
    switch (AppAppearance.current.material) {
      case 1: return BlurStyle.COMPONENT_ULTRA_THIN;
      case 2: return BlurStyle.COMPONENT_THIN;
      case 4: return BlurStyle.COMPONENT_THICK;
      case 5: return BlurStyle.COMPONENT_ULTRA_THICK;
      default: return BlurStyle.COMPONENT_REGULAR;
    }
  }

  static modifier(material: uiMaterial.Material | undefined,
    fallbackColor: ResourceColor = AppColor.GlassControlFallback,
    fallbackShadow: ShadowOptions | undefined = undefined): CompatibleMaterialModifier {
    return new CompatibleMaterialModifier(material, fallbackColor, AppMaterial.fallbackBlur, fallbackShadow);
  }

  static selectModifier(): CompatibleSelectMaterialModifier {
    return new CompatibleSelectMaterialModifier(AppMaterial.InteractiveClean, AppMaterial.Sheet,
      AppMaterial.fallbackBlur);
  }
}

/** API 20 使用背景色和磨砂；旧设备不调用 systemMaterial，也不加载 uiMaterial。 */
class CompatibleMaterialModifier implements AttributeModifier<CommonAttribute> {
  private material: uiMaterial.Material | undefined;
  private fallbackColor: ResourceColor;
  private blur: BlurStyle;
  private fallbackShadow: ShadowOptions | undefined;

  constructor(material: uiMaterial.Material | undefined, fallbackColor: ResourceColor, blur: BlurStyle,
    fallbackShadow: ShadowOptions | undefined = undefined) {
    this.material = material;
    this.fallbackColor = fallbackColor;
    this.blur = blur;
    this.fallbackShadow = fallbackShadow;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    if (PlatformCompat.immersiveMaterial && this.material !== undefined) {
      instance.systemMaterial(this.material);
    } else {
      instance.backgroundColor(this.fallbackColor).backgroundBlurStyle(this.blur);
      if (this.fallbackShadow !== undefined) {
        instance.shadow(this.fallbackShadow);
      }
    }
  }
}

/** 下拉入口和弹出菜单分别应用材质，避免菜单保留系统默认厚背景。 */
class CompatibleSelectMaterialModifier extends CompatibleMaterialModifier {
  private menuMaterial: uiMaterial.Material | undefined;
  private menuBlur: BlurStyle;

  constructor(controlMaterial: uiMaterial.Material | undefined, menuMaterial: uiMaterial.Material | undefined,
    blur: BlurStyle) {
    super(controlMaterial, AppColor.GlassControlFallback, blur);
    this.menuMaterial = menuMaterial;
    this.menuBlur = blur;
  }

  applyNormalAttribute(instance: SelectAttribute): void {
    super.applyNormalAttribute(instance);
    instance.menuBackgroundColor(Color.Transparent);
    if (PlatformCompat.immersiveMaterial && this.menuMaterial !== undefined) {
      instance.menuBackgroundBlurStyle(BlurStyle.NONE).menuSystemMaterial(this.menuMaterial);
    } else {
      instance.menuBackgroundBlurStyle(this.menuBlur);
    }
  }
}

/**
 * System blur presets used by the current frosted-glass surfaces.
 * Legacy blur options for surfaces that do not use native sheet materials.
 */
export class AppGlass {
  static readonly ControlBlur: BlurStyle = BlurStyle.BACKGROUND_THIN;
  static readonly SheetBlur: BlurStyle = BlurStyle.BACKGROUND_REGULAR;

  static readonly ControlOptions: BackgroundBlurStyleOptions = {
    colorMode: ThemeColorMode.SYSTEM,
    adaptiveColor: AdaptiveColor.AVERAGE,
    scale: 0.62,
    policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
    inactiveColor: AppColor.GlassControlFallback
  };

  static readonly SheetOptions: BackgroundBlurStyleOptions = {
    colorMode: ThemeColorMode.DARK,
    adaptiveColor: AdaptiveColor.AVERAGE,
    scale: 0.65,
    policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE,
    inactiveColor: AppColor.GlassSheetFallback
  };

}

export class AppRadius {
  static readonly Xs: number = 4;
  static readonly Sm: number = 8;
  static readonly Md: number = 12;
  static readonly Lg: number = 16;
  static readonly Xl: number = 24;
  static readonly Pill: number = 999;
}

export class AppSpace {
  static readonly Xxs: number = 4;
  static readonly Xs: number = 8;
  static readonly Sm: number = 12;
  static readonly Md: number = 16;
  static readonly Lg: number = 24;
  static readonly Xl: number = 32;
  /** Smartisan 布局：页面左右内容边距。 */
  static readonly PageX: number = 28;
  /** Smartisan 布局：主区块之间的呼吸间距。 */
  static readonly Section: number = 36;
  /** Smartisan 布局：主视觉（封面）与标题之间。 */
  static readonly HeroGap: number = 28;
  /** Smartisan 布局：列表行上下内边距。 */
  static readonly RowY: number = 14;
}

export class AppFont {
  /** 辅助说明、时间戳、次要标签。 */
  static readonly Caption: number = 12;
  /** 正文、输入框、次级列表行。 */
  static readonly Body: number = 14;
  /** 列表主文、菜单行标题。 */
  static readonly BodyL: number = 15;
  /** 分组标题、弹层标题。 */
  static readonly Title: number = 17;
  /** 强调区块标题。 */
  static readonly TitleL: number = 20;
  /** 空态大图标旁说明或少量展示数字。 */
  static readonly Display: number = 24;
  /** 页面标题、播放书名。 */
  static readonly HeroTitle: number = 20;
  /** 极少使用的超大展示字。 */
  static readonly DisplayL: number = 28;
}

/** Smartisan 布局辅 token：圆角与控件尺寸，颜色仍走 AppTheme / ThemeBundles。 */
export class AppLayout {
  /** 播放封面圆角：克制，不做胶囊。 */
  static readonly CoverRadius: number = 10;
  /** 书卡封面圆角，与详情一致偏小。 */
  static readonly CardRadius: number = 8;
  /** 主播控播放键（贴近 Smartisan 100dp 主钮观感）。 */
  static readonly PlayGlyph: number = 56;
  /** 主播控上一章/下一章。 */
  static readonly TransportGlyph: number = 40;
  /** 主播控快进/快退。 */
  static readonly SkipGlyph: number = 24;
  /** 次级工具图标。 */
  static readonly ToolGlyph: number = 22;
  /** 列表行最小高度。 */
  static readonly ListRowMin: number = 72;
  /** 进度条高度：细长低存在感。 */
  static readonly ProgressHeight: number = 3;
  /** Smartisan DiscView 一圈时长（毫秒），匀速旋转。 */
  static readonly VinylSpinMs: number = 15000;
  /** 唱片内封面直径相对外盘；对齐 circle_album_height≈134/360。 */
  static readonly VinylArtRatio: number = 0.40;
  /**
   * 唱臂落在外圈时的 rotation（度）。
   * 参考 CustTonearmView：绝对角 103°，rotation = 103 - 90。
   */
  static readonly VinylArmOuterDeg: number = 13;
  /** 唱臂接近内封：绝对角 120° → rotation 30。 */
  static readonly VinylArmInnerDeg: number = 30;
  /** 落针动画时长（毫秒）。 */
  static readonly VinylArmDropMs: number = 800;
  /** 抬臂归位时长（毫秒）。 */
  static readonly VinylArmResetMs: number = 1000;
}

export class AppMotion {
  static readonly Fast: number = 150;
  static readonly Base: number = 250;
  static readonly Standard: number = 250; // 标准动画时长（与 Base 相同）
  static readonly Slow: number = 350;
  static readonly Page: number = 380;
}

/**
 * 统一动效曲线 token
 * - Standard: 通用进出场（默认）
 * - Emphasized: 大幅位移/页面级强调
 * - Decelerate: 入场（慢出快进）
 * - Accelerate: 出场（快出慢进）
 * - Spring: 轻量弹簧（点选/Tab）
 * - SpringSoft: 柔性弹簧（Sheet/弹层）
 */
export class AppCurve {
  static readonly Standard = curves.cubicBezierCurve(0.2, 0, 0, 1);
  static readonly Emphasized = curves.cubicBezierCurve(0.33, 0, 0.1, 1);
  static readonly Decelerate = curves.cubicBezierCurve(0, 0, 0, 1);
  static readonly Accelerate = curves.cubicBezierCurve(0.4, 0, 1, 1);
  static readonly Spring = curves.springMotion(0.4, 0.85);
  static readonly SpringSoft = curves.springMotion(0.6, 0.9);
}

/**
 * 首页与记录页共用的暖色主题。
 * 走 base/dark element/color.json 双份资源，自动深浅切换。
 */
export class HomeTheme {
  static get BgWarmTop(): ResourceStr {
    return AppTheme.Background;
  }
  static get BgWarmMid(): ResourceStr {
    return AppTheme.Background;
  }
  static get BgNeutral(): ResourceStr {
    return AppTheme.Background;
  }
  /** 状态栏窄条：与 BgNeutral 同色半透明，配合 backdropBlur */
  static get StatusScrim(): ResourceStr {
    const custom: string = AppAppearance.current.backgroundColor;
    return custom.length > 0 ? AppAppearance.withAlpha(custom, 'E6') :
      ThemeBundles.statusScrim(AppTheme.bundleId);
  }
  static get FloatingBarMask(): Resource {
    return ThemeBundles.floatingMask(AppTheme.bundleId);
  }
  static get Accent(): ResourceStr {
    return AppAppearance.current.accent.length > 0 ? AppColor.Brand : $r('app.color.home_accent');
  }
  static get AccentSoft(): ResourceStr {
    return AppAppearance.current.accent.length > 0 ? AppColor.BrandSoft : $r('app.color.home_accent_soft');
  }
  static get TopControlTint(): Resource {
    return ThemeBundles.control(AppTheme.bundleId);
  }
  static get CardSurface(): ResourceStr {
    return AppTheme.Surface;
  }
  static get CardShadow(): Resource {
    return ThemeBundles.shadow(AppTheme.bundleId);
  }
  static get ProgressTrack(): ResourceStr {
    return AppTheme.Divider;
  }
}
