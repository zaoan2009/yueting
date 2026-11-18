/** App 外观偏好。阅读纸张主题独立保存，不随 App 强调色变化。 */
@ObservedV2
export class AppAppearance {
  static readonly defaultAccent: string = '#C4475B';
  private static singleton: AppAppearance | null = null;

  static get current(): AppAppearance {
    if (AppAppearance.singleton === null) {
      AppAppearance.singleton = new AppAppearance();
    }
    return AppAppearance.singleton;
  }

  /** 2 强、3 均衡、4 弱；兼容旧超薄/超厚偏好。 */
  @Trace material: number = 3;
  /** 产品默认银杏强调色（落叶金黄）。 */
  @Trace accent: string = '#8B6914';
  /** 当前仅银杏；桌面图标固定，不随主题切换。 */
  @Trace themeBundleId: string = 'ginkgo-winter';
  /** 空串使用银杏资源底色。 */
  @Trace backgroundColor: string = '';
  /** 空串使用银杏资源表面色。 */
  @Trace surfaceColor: string = '';
  /** 空串使用银杏资源文字色。 */
  @Trace textColor: string = '';
  /** filesDir/theme_bg 下文件名。 */
  @Trace customBackgroundName: string = '';
  /** 解析后的绝对路径；文件缺失时为空，回退银杏暗纹。 */
  @Trace customBackgroundPath: string = '';

  static normalizeMaterial(value: number): number {
    if (value === 1 || value === 2) return 2;
    if (value === 4 || value === 5) return 4;
    return 3;
  }

  static normalizeAccent(value: string): string {
    const hex: string = value.trim().toUpperCase();
    if (!/^#[0-9A-F]{6}$/.test(hex)) return '';
    // 旧银杏金在浅底对比不足，统一迁到合规强调色。
    if (hex === '#E8B02E') return '#8B6914';
    return hex;
  }

  static shade(hex: string, scale: number): string {
    const red: number = Math.round(parseInt(hex.substring(1, 3), 16) * scale);
    const green: number = Math.round(parseInt(hex.substring(3, 5), 16) * scale);
    const blue: number = Math.round(parseInt(hex.substring(5, 7), 16) * scale);
    return '#' + red.toString(16).padStart(2, '0') + green.toString(16).padStart(2, '0') +
      blue.toString(16).padStart(2, '0');
  }

  static foreground(hex: string): string {
    const red: number = parseInt(hex.substring(1, 3), 16);
    const green: number = parseInt(hex.substring(3, 5), 16);
    const blue: number = parseInt(hex.substring(5, 7), 16);
    return red * 0.299 + green * 0.587 + blue * 0.114 > 165 ? '#191919' : '#FFFFFF';
  }

  /** 给实心色加透明度前缀，例如 #99 + RRGGBB。 */
  static withAlpha(hex: string, alphaHex: string): string {
    if (hex.length !== 7) {
      return hex;
    }
    return '#' + alphaHex + hex.substring(1);
  }

  static hasCustomPalette(): boolean {
    const current: AppAppearance = AppAppearance.current;
    return current.backgroundColor.length > 0 || current.surfaceColor.length > 0 ||
      current.textColor.length > 0 || current.customBackgroundName.length > 0 ||
      current.customBackgroundPath.length > 0;
  }
}
