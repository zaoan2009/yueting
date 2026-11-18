import { AppAppearance } from '../model/AppAppearance';
import { AppFont, AppSpace, AppTheme } from '../theme/Theme';
import { WindowUtils } from '../utils/WindowUtils';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { ThemeBundleComponent } from '../components/ThemeBundleComponent';

/** 主题页：银杏默认 + 全局自定义背景/色板；桌面图标固定虎图。 */
@ComponentV2
export struct ThemePage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Local appearance: AppAppearance = AppAppearance.current;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemeBackgroundComponent()
      Column() {
        Row({ space: AppSpace.Sm }) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([AppTheme.TextPrimary])
          }.width(40).height(40).backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.app_icon_back')).onClick(() => this.navStack.pop())
          Text($r('app.string.theme_page_title')).fontSize(AppFont.HeroTitle).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TextPrimary)
          Blank()
        }.width('100%').padding({ top: WindowUtils.getStatusBarHeightVp() + AppSpace.Sm,
          left: AppSpace.PageX, right: AppSpace.PageX, bottom: AppSpace.Sm })
        Scroll() {
          Column() {
            ThemeBundleComponent()
          }.width('100%').constraintSize({ maxWidth: 920 })
          .padding({ left: AppSpace.PageX, right: AppSpace.PageX, top: AppSpace.Sm,
            bottom: WindowUtils.getBottomSafeVp() + AppSpace.Lg })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }.width('100%').height('100%')
    }.width('100%').height('100%')
    .backgroundColor(AppTheme.Background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
