/** 目录标题简化：去掉章节间重复前缀，只保留区分信息。 */
export class ChapterTitleSimplify {
  private static readonly MIN_PREFIX: number = 4;

  static commonPrefix(titles: string[]): string {
    if (titles.length < 2) {
      return '';
    }
    let prefix: string = titles[0];
    for (let index = 1; index < titles.length && prefix.length > 0; index++) {
      const title: string = titles[index];
      let matched: number = 0;
      const limit: number = Math.min(prefix.length, title.length);
      while (matched < limit && prefix.charAt(matched) === title.charAt(matched)) {
        matched++;
      }
      prefix = prefix.substring(0, matched);
    }
    prefix = ChapterTitleSimplify.trimTrailingSeparators(prefix);
    if (prefix.length < ChapterTitleSimplify.MIN_PREFIX) {
      return '';
    }
    let useful: number = 0;
    for (const title of titles) {
      if (ChapterTitleSimplify.stripPrefix(title, prefix).length > 0) {
        useful++;
      }
    }
    if (useful * 2 < titles.length) {
      return '';
    }
    return prefix;
  }

  static displayTitle(title: string, prefix: string, enabled: boolean): string {
    if (!enabled || prefix.length === 0) {
      return title;
    }
    const simplified: string = ChapterTitleSimplify.stripPrefix(title, prefix);
    return simplified.length > 0 ? simplified : title;
  }

  private static stripPrefix(title: string, prefix: string): string {
    if (!title.startsWith(prefix)) {
      return title;
    }
    return ChapterTitleSimplify.trimLeadingSeparators(title.substring(prefix.length));
  }

  private static trimLeadingSeparators(value: string): string {
    let start: number = 0;
    while (start < value.length && ChapterTitleSimplify.isSeparator(value.charAt(start))) {
      start++;
    }
    return value.substring(start);
  }

  private static trimTrailingSeparators(value: string): string {
    let end: number = value.length;
    while (end > 0 && ChapterTitleSimplify.isSeparator(value.charAt(end - 1))) {
      end--;
    }
    return value.substring(0, end);
  }

  private static isSeparator(ch: string): boolean {
    return ch === ' ' || ch === '\t' || ch === '·' || ch === '-' || ch === '—' || ch === '_' ||
      ch === '：' || ch === ':' || ch === '，' || ch === ',' || ch === '。' || ch === '.' ||
      ch === '!' || ch === '！' || ch === '?' || ch === '？' || ch === '、' || ch === '/' ||
      ch === '\\' || ch === '|';
  }
}
