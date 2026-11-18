import { AppAppearance } from '../model/AppAppearance';
import { AppTheme } from './Theme';
import { ThemeBundles } from './ThemeBundles';

/** 仅解析封面呈现；真实图片地址、封面缓存和书籍身份始终由原链路管理。 */
export class CoverTheme {
  static hasSkin(themeBundleId: string = ''): boolean {
    return themeBundleId.length > 0 ? ThemeBundles.hasSkin(themeBundleId) : AppTheme.hasSkin;
  }

  /** @deprecated 使用 hasSkin；保留别名兼容旧调用。 */
  static isPaper(themeBundleId: string = ''): boolean {
    return CoverTheme.hasSkin(themeBundleId);
  }

  static placeholder(themeBundleId: string = ''): Resource {
    if (!CoverTheme.hasSkin(themeBundleId)) {
      return $r('app.media.book_cover_placeholder');
    }
    return ThemeBundles.cover(CoverTheme.resolveId(themeBundleId));
  }

  static localPlaceholder(themeBundleId: string = ''): Resource {
    if (!CoverTheme.hasSkin(themeBundleId)) {
      return $r('app.media.local_book_cover_placeholder');
    }
    return ThemeBundles.localCover(CoverTheme.resolveId(themeBundleId));
  }

  static titleColor(local: boolean = false, themeBundleId: string = ''): ResourceColor {
    if (!CoverTheme.hasSkin(themeBundleId)) {
      return local ? '#493E35' : '#FFF4E6';
    }
    return ThemeBundles.coverText(CoverTheme.resolveId(themeBundleId), local);
  }

  static authorColor(themeBundleId: string = ''): ResourceColor {
    if (!CoverTheme.hasSkin(themeBundleId)) {
      return '#64584B';
    }
    return ThemeBundles.coverAuthor(CoverTheme.resolveId(themeBundleId));
  }

  static titleBackground(themeBundleId: string = ''): ResourceColor {
    if (!CoverTheme.hasSkin(themeBundleId)) {
      return '#AA493E35';
    }
    return ThemeBundles.coverLabel(CoverTheme.resolveId(themeBundleId));
  }

  static edgeColor(themeBundleId: string = ''): ResourceColor {
    if (!CoverTheme.hasSkin(themeBundleId)) {
      return AppTheme.TextSecondary;
    }
    return ThemeBundles.textSecondary(CoverTheme.resolveId(themeBundleId));
  }

  private static resolveId(themeBundleId: string): string {
    if (themeBundleId.length > 0) {
      return ThemeBundles.normalizeId(themeBundleId);
    }
    return ThemeBundles.normalizeId(AppAppearance.current.themeBundleId);
  }
}
