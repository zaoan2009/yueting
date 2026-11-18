import { AppColor } from '../theme/Theme';
import { PlatformCompat } from '../utils/PlatformCompat';
import { ThemeIconComponent } from './ThemeIconComponent';
import { ThemeIconRole } from '../theme/ThemeIcons';

class AvatarImageQuality implements AttributeModifier<ImageAttribute> {
  applyNormalAttribute(instance: ImageAttribute): void {
    // 图片边缘抗锯齿从 API 23 起支持；旧系统沿用图片圆角和缩放插值。
    if (PlatformCompat.supports(23)) {
      instance.antialiased(true);
    }
  }
}

@ComponentV2
export struct AccountAvatar {
  @Param uri: string = '';
  @Param avatarSize: number = 28;
  @Local failedUri: string = '';
  private imageQuality: AvatarImageQuality = new AvatarImageQuality();

  build() {
    Stack() {
      Circle()
        .width(this.avatarSize)
        .height(this.avatarSize)
        .foregroundColor(AppColor.Brand)
      ThemeIconComponent({
        role: ThemeIconRole.Profile,
        symbol: $r('sys.symbol.person_fill'),
        iconSize: this.avatarSize * 0.64,
        tint: Color.White
      })
      if (this.uri.length > 0 && this.failedUri !== this.uri) {
        Image(this.uri)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.avatarSize / 2)
          .interpolation(ImageInterpolation.Medium)
          .attributeModifier(this.imageQuality)
          .onError(() => { this.failedUri = this.uri; })
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .accessibilityText($r('app.string.account_avatar'))
  }
}
