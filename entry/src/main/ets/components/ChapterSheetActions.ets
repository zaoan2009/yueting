import { AppColor, AppFont, AppSpace } from '../theme/Theme';

/** 两种章节弹框共用紧凑工具栏，图标按钮保留无障碍说明。 */
@ComponentV2
export struct ChapterSheetActions {
  @Param descending: boolean = false;
  /** 有声书显示离线下载入口；电子书/漫画不显示。 */
  @Param showDownload: boolean = false;
  @Event onOrder: () => void = () => {};
  @Event onTop: () => void = () => {};
  @Event onBottom: () => void = () => {};
  @Event onDownload: () => void = () => {};

  @Builder
  edgeButton(bottom: boolean) {
    Button({ type: ButtonType.Normal }) {
      SymbolGlyph(bottom ? $r('sys.symbol.arrow_down_to_line') : $r('sys.symbol.arrow_up_to_line'))
        .fontSize(18).fontColor([$r('sys.color.font_secondary')])
    }.width(40).height(32).padding(0).backgroundColor(Color.Transparent)
    .accessibilityText(bottom ? $r('app.string.chapter_back_bottom') : $r('app.string.chapter_back_top'))
    .onClick((): void => { if (bottom) this.onBottom(); else this.onTop(); })
  }

  build() {
    Row({ space: AppSpace.Sm }) {
      Button({ type: ButtonType.Capsule }) {
        Row({ space: 6 }) {
          SymbolGlyph(this.descending ? $r('sys.symbol.arrow_down') : $r('sys.symbol.arrow_up'))
            .fontSize(16).fontColor([$r('sys.color.font_secondary')])
          Text(this.descending ? $r('app.string.chapter_order_descending') : $r('app.string.chapter_order_ascending'))
            .fontSize(AppFont.Caption).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        }
      }.height(32).padding({ left: 12, right: 12 }).backgroundColor($r('sys.color.comp_background_tertiary'))
      .accessibilityText(this.descending ? $r('app.string.chapter_order_descending') : $r('app.string.chapter_order_ascending'))
      .onClick((): void => this.onOrder())
      Blank()
      if (this.showDownload) {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.arrow_down_circle'))
            .fontSize(20)
            .fontColor([AppColor.Brand])
        }
        .width(40)
        .height(32)
        .padding(0)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(16)
        .accessibilityText($r('app.string.download_panel_title'))
        .id('chapter-sheet-download')
        .onClick((): void => this.onDownload())
      }
      Row() {
        this.edgeButton(false)
        Divider().vertical(true).height(14).color($r('sys.color.comp_divider'))
        this.edgeButton(true)
      }.borderRadius(16).clip(true).backgroundColor($r('sys.color.comp_background_tertiary'))
    }.width('100%').padding({ left: AppSpace.Lg, right: AppSpace.Lg })
  }
}
