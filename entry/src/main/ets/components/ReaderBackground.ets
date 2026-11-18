/** 阅读页与设置预览共用的底色 / 自定义图片 / 内置书籍背景，图片上保留可调蒙层。 */
import { fileUri } from '@kit.CoreFileKit';
import { ReaderPattern, ReaderPalette, ReaderImageMode } from '../model/ReaderTheme';
import { ReaderBuiltinBackground } from '../model/ReaderBuiltinBackground';

@ComponentV2
export struct ReaderBackground {
  @Param palette: ReaderPalette = new ReaderPalette();
  @Param pattern: string = ReaderPattern.None;
  /** 沙箱绝对路径，或 builtin:<id>。 */
  @Param bgImagePath: string = '';
  @Param imageMode: ReaderImageMode = ReaderImageMode.Cover;
  @Param overlayAlpha: number = 0.35;

  private hasImage(): boolean {
    if (this.pattern !== ReaderPattern.Image || this.bgImagePath.length === 0) return false;
    if (ReaderBuiltinBackground.isBuiltin(this.bgImagePath)) {
      return ReaderBuiltinBackground.find(this.bgImagePath) !== null;
    }
    return this.bgImagePath.indexOf('/') === 0;
  }

  private objectFit(): ImageFit {
    if (this.imageMode === ReaderImageMode.Contain) return ImageFit.Contain;
    if (this.imageMode === ReaderImageMode.Stretch) return ImageFit.Fill;
    return ImageFit.Cover;
  }

  private builtinMedia(): Resource {
    const item = ReaderBuiltinBackground.find(this.bgImagePath);
    return item !== null ? item.media : $r('app.media.reader_bg_parchment');
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.palette.background)

      if (this.hasImage()) {
        if (ReaderBuiltinBackground.isBuiltin(this.bgImagePath)) {
          if (this.imageMode === ReaderImageMode.Tile) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundImage(this.builtinMedia(), ImageRepeat.XY)
              .backgroundImageSize(ImageSize.Auto)
              .backgroundImagePosition(Alignment.TopStart)
          } else {
            Image(this.builtinMedia())
              .width('100%')
              .height('100%')
              .objectFit(this.objectFit())
              .interpolation(ImageInterpolation.Medium)
          }
        } else if (this.imageMode === ReaderImageMode.Tile) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundImage(fileUri.getUriFromPath(this.bgImagePath), ImageRepeat.XY)
            .backgroundImageSize(ImageSize.Auto)
            .backgroundImagePosition(Alignment.TopStart)
        } else {
          Image(fileUri.getUriFromPath(this.bgImagePath))
            .width('100%')
            .height('100%')
            .objectFit(this.objectFit())
            .interpolation(ImageInterpolation.Medium)
        }
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.palette.background)
          .opacity(this.overlayAlpha)
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
