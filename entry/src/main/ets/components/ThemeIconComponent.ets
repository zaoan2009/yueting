import { AppAppearance } from '../model/AppAppearance';
import { AppTheme } from '../theme/Theme';
import { ThemeBundles } from '../theme/ThemeBundles';
import { ThemeIconRole, ThemeIcons } from '../theme/ThemeIcons';

/** 保留系统符号回退，让已有按钮的点击区域与无障碍语义保持原位。 */
@ComponentV2
export struct ThemeIconComponent {
  @Param role: ThemeIconRole = ThemeIconRole.None;
  @Param symbol: Resource = $r('sys.symbol.magnifyingglass');
  @Param iconSize: number = 24;
  @Param tint: ResourceColor = AppTheme.TextPrimary;
  @Local appearance: AppAppearance = AppAppearance.current;

  build() {
    Stack() {
      if (ThemeBundles.hasSkin(this.appearance.themeBundleId) && this.role !== ThemeIconRole.None) {
        Image(ThemeIcons.paper(this.role))
          .width(this.iconSize).height(this.iconSize).objectFit(ImageFit.Contain)
          .fillColor(this.tint)
          .key(`theme-icon:${this.appearance.themeBundleId}:${this.role}`)
      } else {
        SymbolGlyph(this.symbol).fontSize(this.iconSize).fontColor([this.tint])
      }
    }.width(this.iconSize).height(this.iconSize)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}
