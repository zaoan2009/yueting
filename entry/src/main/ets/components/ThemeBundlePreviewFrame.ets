import { AppThemeBundle } from '../model/AppThemeBundle';
import { ThemeBundles } from '../theme/ThemeBundles';

/** 套装示例页共用的迷你手机框；内容由调用方 Builder 注入。 */
@ComponentV2
export struct ThemeBundlePreviewFrame {
  @Param bundle: AppThemeBundle = ThemeBundles.resolve(ThemeBundles.GinkgoId);
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  private emptyContent() {
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(ThemeBundles.backgroundImage())
        .width('100%').height('100%').objectFit(ImageFit.Cover)
      Column() {
        this.content()
      }.width('100%').height('100%').padding(8)
    }.width(120).height(168).borderRadius(12).clip(true)
    .backgroundColor(ThemeBundles.background())
    .border({ width: 1, color: ThemeBundles.divider() })
  }
}
