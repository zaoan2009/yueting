import { AppSpace, AppFont, AppTheme } from '../theme/Theme';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { WindowUtils } from '../utils/WindowUtils';

class NoticeSection {
  id: string;
  title: ResourceStr;
  paragraphs: ResourceStr[];

  constructor(id: string, title: ResourceStr, paragraphs: ResourceStr[]) {
    this.id = id;
    this.title = title;
    this.paragraphs = paragraphs;
  }
}

/** 开源声明:与仓库 THIRD_PARTY_NOTICES.md 保持一致,只声明实际引入的开源组件和许可边界。 */
const NOTICE_SECTIONS: NoticeSection[] = [
  new NoticeSection('thanks', $r('app.string.open_source_section_thanks'), [
    $r('app.string.open_source_thanks_body')
  ]),
  new NoticeSection('engine', $r('app.string.open_source_section_engine'), [
    $r('app.string.open_source_engine_body')
  ]),
  new NoticeSection('components', $r('app.string.open_source_section_components'), [
    $r('app.string.open_source_quickjs'), $r('app.string.open_source_binding'),
    $r('app.string.open_source_napi'), $r('app.string.open_source_crypto')
  ]),
  new NoticeSection('boundary', $r('app.string.open_source_section_boundary'), [
    $r('app.string.open_source_boundary_body')
  ]),
  new NoticeSection('execution', $r('app.string.open_source_section_execution'), [
    $r('app.string.open_source_execution_body')
  ]),
  new NoticeSection('license', $r('app.string.open_source_section_license'), [
    $r('app.string.open_source_license_body')
  ])
];

@ComponentV2
export struct OpenSourcePage {
  @Param navStack: NavPathStack = new NavPathStack();

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemeBackgroundComponent()
      Column() {
        this.buildHeader()

        Scroll() {
          Column({ space: AppSpace.Lg }) {
            ForEach(NOTICE_SECTIONS, (sec: NoticeSection) => {
              Column({ space: AppSpace.Sm }) {
                Text(sec.title)
                  .fontSize(AppFont.BodyL)
                  .fontColor(AppTheme.TextPrimary)
                  .fontWeight(FontWeight.Bold)
                  .width('100%')

                ForEach(sec.paragraphs, (p: ResourceStr) => {
                  Text(p)
                    .fontSize(AppFont.Body)
                    .fontColor(AppTheme.TextSecondary)
                    .lineHeight(22)
                    .width('100%')
                }, (p: ResourceStr, index: number) => `${sec.id}-${index}`)
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: AppSpace.Lg, right: AppSpace.Lg })
            }, (sec: NoticeSection) => sec.id)
          }
          .width('100%')
          .padding({ bottom: WindowUtils.getBottomSafeVp() + AppSpace.Xl })
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

  @Builder
  buildHeader() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([AppTheme.TextPrimary])
        .onClick(() => this.navStack.pop())
      Text($r('app.string.about_open_source'))
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
  }
}