import { AppSpace, AppFont, AppRadius, AppTheme } from '../theme/Theme';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { WindowUtils } from '../utils/WindowUtils';

@ComponentV2
export struct CompliancePage {
  @Param navStack: NavPathStack = new NavPathStack();

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemeBackgroundComponent()
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([AppTheme.TextPrimary])
            .onClick(() => this.navStack.pop())
          Text($r('app.string.about_compliance_title'))
            .fontSize(AppFont.Title)
            .fontColor(AppTheme.TextPrimary)
            .fontWeight(FontWeight.Bold)
            .margin({ left: AppSpace.Sm })
        }
        .width('100%')
        .padding({
          top: WindowUtils.getStatusBarHeightVp() + AppSpace.Sm,
          left: AppSpace.Md, right: AppSpace.Md, bottom: AppSpace.Md
        })

        Scroll() {
          Column({ space: AppSpace.Lg }) {
            Column({ space: AppSpace.Sm }) {
              Text($r('app.string.about_compliance_title'))
                .fontSize(AppFont.BodyL)
                .fontColor(AppTheme.TextPrimary)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Text($r('app.string.about_compliance_body'))
                .fontSize(AppFont.Body)
                .fontColor(AppTheme.TextSecondary)
                .lineHeight(22)
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(AppSpace.Lg)
            .backgroundColor(AppTheme.Surface)
            .borderRadius(AppRadius.Lg)

            Column({ space: AppSpace.Sm }) {
              Text($r('app.string.about_usage_title'))
                .fontSize(AppFont.BodyL)
                .fontColor(AppTheme.TextPrimary)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Text($r('app.string.about_usage_body'))
                .fontSize(AppFont.Body)
                .fontColor(AppTheme.TextSecondary)
                .lineHeight(22)
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(AppSpace.Lg)
            .backgroundColor(AppTheme.Surface)
            .borderRadius(AppRadius.Lg)
          }
          .width('100%')
          .padding({
            left: AppSpace.Md, right: AppSpace.Md,
            bottom: WindowUtils.getBottomSafeVp() + AppSpace.Xl
          })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.Background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
