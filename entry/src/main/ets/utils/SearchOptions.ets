import { Book } from '../model/Book';

class SearchTextMatch {
  tier: number = 0;
  quality: number = 0;
}

class ScoredSearchBook {
  book: Book;
  index: number;
  titleTier: number;
  titleQuality: number;
  authorTier: number;
  authorQuality: number;

  constructor(book: Book, index: number, titleTier: number, titleQuality: number,
    authorTier: number, authorQuality: number) {
    this.book = book;
    this.index = index;
    this.titleTier = titleTier;
    this.titleQuality = titleQuality;
    this.authorTier = authorTier;
    this.authorQuality = authorQuality;
  }
}

export class SearchOptions {
  static matchesSourceType(type: number | undefined, textOnly: boolean, audioOnly: boolean): boolean {
    if (!textOnly && !audioOnly) return true;
    return (textOnly && (type === 0 || type === 3)) || (audioOnly && type === 1);
  }

  static matchesContentType(type: 'audio' | 'text' | 'comic', textOnly: boolean, audioOnly: boolean): boolean {
    if (!textOnly && !audioOnly) return true;
    return (textOnly && type === 'text') || (audioOnly && type === 'audio');
  }

  static matches(name: string, author: string, keyword: string, exact: boolean, byAuthor: boolean): boolean {
    if (!exact && !byAuthor) return true;
    const value = (byAuthor ? author : name).trim().toLocaleLowerCase();
    const query = keyword.trim().toLocaleLowerCase();
    return exact ? value === query : value.includes(query);
  }

  // 输入按最新优先排列，只保留能连续排入两行的前缀。
  static visibleCount(widths: number[], available: number, gap: number): number {
    if (available <= 0) return widths.length;
    let row = 1;
    let used = 0;
    for (let i = 0; i < widths.length; i++) {
      const width = Math.min(widths[i], available);
      if (used > 0 && used + gap + width > available) {
        row++;
        used = 0;
      }
      if (row > 2) return i;
      used += (used > 0 ? gap : 0) + width;
    }
    return widths.length;
  }

  /**
   * 跨源合并后按书名相关度重排：完全匹配优先，其次核心书名一致 / 前缀 / 包含；
   * 同等级保留先到达结果（index 更小）在前。
   */
  static rankBooks(books: Book[], keyword: string): Book[] {
    if (books.length <= 1) return books;
    const normalizedKeyword: string = SearchOptions.normalizeSearchText(keyword);
    if (normalizedKeyword.length === 0) return books;
    const scored: ScoredSearchBook[] = [];
    for (let index = 0; index < books.length; index++) {
      scored.push(SearchOptions.scoreBook(books[index], normalizedKeyword, index));
    }
    scored.sort((left: ScoredSearchBook, right: ScoredSearchBook): number => {
      if (left.titleTier !== right.titleTier) return right.titleTier - left.titleTier;
      if (left.titleQuality !== right.titleQuality) return right.titleQuality - left.titleQuality;
      if (left.authorTier !== right.authorTier) return right.authorTier - left.authorTier;
      if (left.authorQuality !== right.authorQuality) return right.authorQuality - left.authorQuality;
      return left.index - right.index;
    });
    const ranked: Book[] = [];
    for (const item of scored) {
      ranked.push(item.book);
    }
    return ranked;
  }

  private static scoreBook(book: Book, normalizedKeyword: string, index: number): ScoredSearchBook {
    const title: string = SearchOptions.normalizeSearchText(book.title);
    const author: string = SearchOptions.normalizeSearchText(book.author);
    const titleMatch: SearchTextMatch = SearchOptions.titleMatch(title, normalizedKeyword);
    const authorMatch: SearchTextMatch = SearchOptions.textMatch(author, normalizedKeyword);
    return new ScoredSearchBook(book, index, titleMatch.tier, titleMatch.quality,
      authorMatch.tier, authorMatch.quality);
  }

  /** 书名等级：6 完全一致、5 去除集数/装饰后一致、4 前缀、3 连续包含。 */
  private static titleMatch(value: string, keyword: string): SearchTextMatch {
    const match: SearchTextMatch = new SearchTextMatch();
    if (value.length === 0 || keyword.length === 0) return match;
    if (value === keyword) {
      match.tier = 6;
      match.quality = 10000;
      return match;
    }
    const coreValue: string = SearchOptions.normalizeCoreTitle(value);
    const coreKeyword: string = SearchOptions.normalizeCoreTitle(keyword);
    if (coreValue.length > 0 && coreKeyword.length > 0 && coreValue === coreKeyword) {
      match.tier = 5;
      match.quality = 10000 - Math.min(3000, Math.abs(value.length - keyword.length) * 80);
      return match;
    }
    const direct: SearchTextMatch = SearchOptions.textMatch(value, keyword);
    if (direct.tier === 3) match.tier = 4;
    else if (direct.tier === 2) match.tier = 3;
    match.quality = direct.quality;
    return match;
  }

  /** 普通字段：3 前缀、2 连续包含；完全一致记为 4。 */
  private static textMatch(value: string, keyword: string): SearchTextMatch {
    const match: SearchTextMatch = new SearchTextMatch();
    if (value.length === 0 || keyword.length === 0) return match;
    if (value === keyword) {
      match.tier = 4;
      match.quality = 10000;
      return match;
    }
    const lengthDelta: number = Math.max(0, value.length - keyword.length);
    if (value.startsWith(keyword)) {
      match.tier = 3;
      match.quality = 9000 + Math.max(0, 1000 - lengthDelta * 40);
      return match;
    }
    const directIndex: number = value.indexOf(keyword);
    if (directIndex >= 0) {
      match.tier = 2;
      match.quality = 7000 + Math.max(0, 1000 - directIndex * 80 - lengthDelta * 25);
    }
    return match;
  }

  static normalizeSearchText(value: string): string {
    return value.trim().toLowerCase()
      .replace(/[\u200B-\u200D\uFEFF]/g, '')
      .replace(/\s+/g, '')
      .replace(/[《》【】\[\]（）()「」『』"“”'‘’.,，。:：;；!！?？、·_\-…]/g, '');
  }

  static normalizeCoreTitle(value: string): string {
    if (value.length === 0) return '';
    let core: string = value;
    const prefixes: string[] = ['已完结', '完结', '全本', '精品', '精校', '校对', '免费'];
    const suffixes: string[] = ['无删减版', '完整版', '精校版', '校对版', '番外篇', '有声版', '听书版',
      '全集', '全本', '完结', '番外'];
    for (const prefix of prefixes) {
      if (core.startsWith(prefix) && core.length >= prefix.length + 2) {
        core = core.substring(prefix.length);
        break;
      }
    }
    for (const suffix of suffixes) {
      if (core.endsWith(suffix) && core.length >= suffix.length + 2) {
        core = core.substring(0, core.length - suffix.length);
        break;
      }
    }
    // 去掉“第1集/第01章/第一回”及之后的分集尾巴，让合集名能与关键词对齐。
    const episodeIndex: number = core.search(/第[0-9零一二三四五六七八九十百千两]+/);
    if (episodeIndex >= 2) {
      core = core.substring(0, episodeIndex);
    }
    while (core.endsWith('.')) {
      core = core.substring(0, core.length - 1);
    }
    return core.length >= 2 ? core : value;
  }
}
