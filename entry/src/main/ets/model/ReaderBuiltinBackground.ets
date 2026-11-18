/**
 * 阅读页内置书籍背景。
 * 偏好里用 builtin:<id> 存选中项；自定义相册图仍用沙箱绝对路径。
 */

export class ReaderBuiltinBackground {
  id: string = '';
  label: Resource = $r('app.string.reader_bg_parchment');
  media: Resource = $r('app.media.reader_bg_parchment');
  /** 叠字/蒙层底色，参与图片主题配色 */
  wash: string = '#F3E6C8';
  /** 推荐正文字色 */
  fontColor: string = '#2D2925';
  isDark: boolean = false;

  static readonly PREFIX: string = 'builtin:';

  static of(id: string, label: Resource, media: Resource, wash: string, fontColor: string,
    isDark: boolean = false): ReaderBuiltinBackground {
    const value = new ReaderBuiltinBackground();
    value.id = id;
    value.label = label;
    value.media = media;
    value.wash = wash;
    value.fontColor = fontColor;
    value.isDark = isDark;
    return value;
  }

  static token(id: string): string {
    return `${ReaderBuiltinBackground.PREFIX}${id}`;
  }

  static isBuiltin(path: string): boolean {
    return typeof path === 'string' && path.indexOf(ReaderBuiltinBackground.PREFIX) === 0;
  }

  static idFrom(path: string): string {
    return ReaderBuiltinBackground.isBuiltin(path) ?
      path.substring(ReaderBuiltinBackground.PREFIX.length) : '';
  }

  static find(idOrPath: string): ReaderBuiltinBackground | null {
    const id = ReaderBuiltinBackground.isBuiltin(idOrPath) ?
      ReaderBuiltinBackground.idFrom(idOrPath) : idOrPath;
    if (id.length === 0) return null;
    const all = ReaderBuiltinBackground.all();
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) return all[i];
    }
    return null;
  }

  static all(): ReaderBuiltinBackground[] {
    return [
      ReaderBuiltinBackground.of('parchment', $r('app.string.reader_bg_parchment'),
        $r('app.media.reader_bg_parchment'), '#F3E6C8', '#2D2925'),
      ReaderBuiltinBackground.of('xuan', $r('app.string.reader_bg_xuan'),
        $r('app.media.reader_bg_xuan'), '#F7F2E8', '#2C2A26'),
      ReaderBuiltinBackground.of('sage', $r('app.string.reader_bg_sage'),
        $r('app.media.reader_bg_sage'), '#E4EDDF', '#28322A'),
      ReaderBuiltinBackground.of('blush', $r('app.string.reader_bg_blush'),
        $r('app.media.reader_bg_blush'), '#F6E4D8', '#3A2A24'),
      // 与主题页同一张银杏插画，避免阅读另用纸纹图造成「不匹配主题」
      ReaderBuiltinBackground.of('ginkgo', $r('app.string.reader_bg_ginkgo'),
        $r('app.media.theme_ginkgo_background'), '#F7F4EE', '#3A2E14'),
      ReaderBuiltinBackground.of('dusk', $r('app.string.reader_bg_dusk'),
        $r('app.media.reader_bg_dusk'), '#2A3038', '#D8D6D0', true)
    ];
  }
}
