import { HomeBlockSection } from '../../model/BookSource';
import { LocalRuleSource } from '../../model/LocalRuleSource';
import { BookSourceService } from '../BookSourceService';
import { PreferenceService } from '../PreferenceService';
import { SourceDataService } from '../SourceDataService';
import { LocalRulePanelService } from './LocalRulePanelService';
import { LocalRuleSourceRepository } from './LocalRuleSourceRepository';
/** 历史首页偏好：曾表示全网榜单；现仅作迁移识别，不再进入榜单页。 */
const LEGACY_RANKING_HOME_URL: string = 'home://rankings';

/** 首页内容分段：有声书。 */
export const HOME_CONTENT_KIND_AUDIO: number = 1;
/** 首页内容分段：电子书。 */
export const HOME_CONTENT_KIND_TEXT: number = 2;

export class HomeSourceCategory {
  name: string;
  url: string;

  constructor(name: string, url: string) {
    this.name = name;
    this.url = url;
  }
}

export class HomeSourceContent {
  categories: HomeSourceCategory[] = [];
  blocks: HomeBlockSection[] = [];
  loadedAt: number = 0;
}

class HomeSourceLoad {
  content: HomeSourceContent = new HomeSourceContent();
  listeners: Array<(content: HomeSourceContent) => void> = [];
  promise: Promise<HomeSourceContent> = Promise.resolve(this.content);
}

/** 首页使用用户选择的已启用小说或听书发现源，复用现有导入源发现链路。 */
export class HomeSourceService {
  private static readonly CACHE_TTL_MS: number = 5 * 60 * 1000;
  private static cache: Map<string, HomeSourceContent> = new Map();
  private static pending: Map<string, HomeSourceLoad> = new Map();
  private static revision: string = '';

  private static syncRevision(): string {
    const revision = `${SourceDataService.getInvalidationCounter()}:${LocalRuleSourceRepository.getLoginRevision()}`;
    if (revision !== HomeSourceService.revision) {
      HomeSourceService.cache.clear();
      HomeSourceService.pending.clear();
      HomeSourceService.revision = revision;
    }
    return revision;
  }

  /** 有界内存缓存；书源定义或登录状态变化即失效，下拉刷新绕过缓存。 */
  static async loadHome(source: LocalRuleSource, forceRefresh: boolean = false,
    onUpdate: (content: HomeSourceContent) => void = (): void => {}): Promise<HomeSourceContent> {
    const revision = HomeSourceService.syncRevision();
    const key = source.bookSourceUrl;
    const cached = HomeSourceService.cache.get(key);
    if (!forceRefresh && cached !== undefined && Date.now() - cached.loadedAt < HomeSourceService.CACHE_TTL_MS) {
      HomeSourceService.cache.delete(key);
      HomeSourceService.cache.set(key, cached);
      onUpdate(cached);
      return cached;
    }
    const active = HomeSourceService.pending.get(key);
    if (active !== undefined) {
      active.listeners.push(onUpdate);
      if (active.content.categories.length > 0 || active.content.blocks.length > 0) onUpdate(active.content);
      return active.promise;
    }
    const task = new HomeSourceLoad();
    task.listeners.push(onUpdate);
    HomeSourceService.pending.set(key, task);
    task.promise = HomeSourceService.fetchHome(source, task).then((content: HomeSourceContent): HomeSourceContent => {
      if (revision === HomeSourceService.syncRevision() && HomeSourceService.pending.get(key) === task &&
        content.blocks.length > 0) {
        content.loadedAt = Date.now();
        HomeSourceService.cache.delete(key);
        HomeSourceService.cache.set(key, content);
        while (HomeSourceService.cache.size > 4) {
          const oldest = HomeSourceService.cache.keys().next();
          if (oldest.done) break;
          HomeSourceService.cache.delete(oldest.value);
        }
      }
      return content;
    }).finally((): void => {
      task.listeners = [];
      if (HomeSourceService.pending.get(key) === task) HomeSourceService.pending.delete(key);
    });
    return task.promise;
  }

  private static async fetchHome(source: LocalRuleSource, task: HomeSourceLoad): Promise<HomeSourceContent> {
    task.content.categories = await HomeSourceService.getCategories(source);
    HomeSourceService.notifyHome(task);
    task.content.blocks = await HomeSourceService.getHomeBlocks(source, task.content.categories,
      (blocks: HomeBlockSection[]): void => {
        task.content.blocks = blocks;
        HomeSourceService.notifyHome(task);
      });
    return task.content;
  }

  private static notifyHome(task: HomeSourceLoad): void {
    for (const listener of task.listeners) listener(task.content);
  }

  static isEligible(source: LocalRuleSource): boolean {
    return source.enabled && (source.isAudio() || source.isText()) && source.canExecute() &&
      HomeSourceService.hasHomeContent(source) &&
      !source.bookSourceUrl.startsWith('builtin://');
  }

  static matchesKind(source: LocalRuleSource, kind: number): boolean {
    if (kind === HOME_CONTENT_KIND_AUDIO) return source.isAudio();
    if (kind === HOME_CONTENT_KIND_TEXT) return source.isText();
    return source.isAudio() || source.isText();
  }

  static normalizeKind(kind: number): number {
    return kind === HOME_CONTENT_KIND_TEXT ? HOME_CONTENT_KIND_TEXT : HOME_CONTENT_KIND_AUDIO;
  }

  static async getHomeContentKind(): Promise<number> {
    const saved = await PreferenceService.getHomeContentKind();
    if (saved === HOME_CONTENT_KIND_AUDIO || saved === HOME_CONTENT_KIND_TEXT) return saved;
    // 未设置时按旧单键源类型推断；否则默认有声。
    const legacyUrl = await PreferenceService.getHomeSourceUrlForKind(0);
    if (legacyUrl && legacyUrl !== LEGACY_RANKING_HOME_URL) {
      const source = await SourceDataService.getSourceByUrl(legacyUrl);
      if (source instanceof LocalRuleSource && HomeSourceService.isEligible(source)) {
        return source.isAudio() ? HOME_CONTENT_KIND_AUDIO : HOME_CONTENT_KIND_TEXT;
      }
    }
    const audioSources = await HomeSourceService.getSources(HOME_CONTENT_KIND_AUDIO);
    if (audioSources.length > 0) return HOME_CONTENT_KIND_AUDIO;
    const textSources = await HomeSourceService.getSources(HOME_CONTENT_KIND_TEXT);
    if (textSources.length > 0) return HOME_CONTENT_KIND_TEXT;
    return HOME_CONTENT_KIND_AUDIO;
  }

  static async setHomeContentKind(kind: number): Promise<void> {
    await PreferenceService.setHomeContentKind(HomeSourceService.normalizeKind(kind));
  }

  static async getSources(kind: number = 0): Promise<LocalRuleSource[]> {
    const sources = await SourceDataService.getSources();
    const eligibleSources: LocalRuleSource[] = [];
    for (const source of sources) {
      if (!(source instanceof LocalRuleSource) || !HomeSourceService.isEligible(source)) continue;
      if (kind === 0 || HomeSourceService.matchesKind(source, kind)) eligibleSources.push(source);
    }
    return eligibleSources;
  }

  static selectAvailable(sources: LocalRuleSource[], preferredUrl: string,
    kind: number = 0): LocalRuleSource | undefined {
    const eligible = sources.filter((source: LocalRuleSource): boolean =>
      HomeSourceService.isEligible(source) &&
      (kind === 0 || HomeSourceService.matchesKind(source, kind)));
    return eligible.find((source: LocalRuleSource): boolean => source.bookSourceUrl === preferredUrl) ??
      eligible.find((source: LocalRuleSource): boolean => HomeSourceService.hasHomeContent(source)) ?? eligible[0];
  }

  /**
   * 解析指定分段的首页源：偏好有效则用偏好；无效时落到该类型第一个可用源并写回。
   * 该类型完全无可用源返回 undefined。
   */
  static async getSelectedSource(kind: number = 0): Promise<LocalRuleSource | undefined> {
    const resolvedKind = kind === 0 ?
      await HomeSourceService.getHomeContentKind() : HomeSourceService.normalizeKind(kind);
    let preferred = await PreferenceService.getHomeSourceUrlForKind(resolvedKind);
    if (preferred === LEGACY_RANKING_HOME_URL) preferred = '';
    if (preferred) {
      const source = await SourceDataService.getSourceByUrl(preferred);
      if (source instanceof LocalRuleSource && HomeSourceService.isEligible(source) &&
        HomeSourceService.matchesKind(source, resolvedKind)) {
        // 仅在双键尚未写入时迁入一次；setHomeSourceUrlForKind 对相同值会跳过发事件。
        try {
          await PreferenceService.setHomeSourceUrlForKind(resolvedKind, source.bookSourceUrl);
        } catch (_error) { /* ignore */ }
        return source;
      }
    }
    const sources = await HomeSourceService.getSources(resolvedKind);
    const fallback = HomeSourceService.selectAvailable(sources, '', resolvedKind);
    if (fallback === undefined) return undefined;
    try {
      await PreferenceService.setHomeSourceUrlForKind(resolvedKind, fallback.bookSourceUrl);
    } catch (_error) {
      // 写回失败仍返回可用源，保证本次首页能展示源站推荐。
    }
    return fallback;
  }

  static async setSelectedSource(sourceUrl: string, kind: number = 0): Promise<void> {
    const source = await SourceDataService.getSourceByUrl(sourceUrl);
    if (!(source instanceof LocalRuleSource) || !HomeSourceService.isEligible(source)) {
      throw new Error('首页源必须已启用且支持发现');
    }
    const resolvedKind = kind === 0 ?
      (source.isAudio() ? HOME_CONTENT_KIND_AUDIO : HOME_CONTENT_KIND_TEXT) :
      HomeSourceService.normalizeKind(kind);
    if (!HomeSourceService.matchesKind(source, resolvedKind)) {
      throw new Error('首页源类型与当前分段不一致');
    }
    await PreferenceService.setHomeSourceUrlForKind(resolvedKind, sourceUrl);
  }

  /** 是否存在任一类型的可用发现源。 */
  static async hasAnyEligibleSource(): Promise<boolean> {
    const sources = await HomeSourceService.getSources(0);
    return sources.length > 0;
  }

  static hasHomeContent(source: LocalRuleSource): boolean {
    return source.enabledExplore && source.exploreUrl.trim().length > 0;
  }

  static async getCategories(source: LocalRuleSource): Promise<HomeSourceCategory[]> {
    if (!source.enabledExplore || !source.exploreUrl.trim()) return [];
    const panel = await LocalRulePanelService.load(source, false);
    const categories: HomeSourceCategory[] = [];
    const seen = new Set<string>();
    for (const entry of panel.entries) {
      if (!entry.url.trim() || entry.action || seen.has(entry.url)) continue;
      seen.add(entry.url);
      categories.push(new HomeSourceCategory(entry.title, entry.url));
    }
    return categories;
  }

  static async getHomeBlocks(source: LocalRuleSource,
    categories: HomeSourceCategory[],
    onUpdate: (blocks: HomeBlockSection[]) => void = (): void => {}): Promise<HomeBlockSection[]> {
    // 只预览前四个发现分类；各分类独立失败，避免一个分类阻断整个首页。
    let failureMessage: string = '';
    let failed: boolean = false;
    let completed: number = 0;
    const blocks: HomeBlockSection[] = categories.slice(0, 4).map((category: HomeSourceCategory): HomeBlockSection => {
      const block: HomeBlockSection = {
        title: category.name, books: [], moreUrl: category.url, layout: 'horizontal',
        sourceName: source.bookSourceName, sourceUrl: source.bookSourceUrl
      };
      return block;
    });
    const loadBlock = async (block: HomeBlockSection): Promise<void> => {
      try {
        const result = await BookSourceService.getExploreBooksByUrl(source, block.moreUrl, 1, 12);
        block.books = result.books.slice(0, 12);
        completed++;
        if (block.books.length > 0) {
          onUpdate(blocks.filter((item: HomeBlockSection): boolean => item.books.length > 0));
        }
      } catch (error) {
        failed = true;
        failureMessage = error instanceof Error ? error.message : String(error);
      }
    };
    // DOM 宿主串行执行，四个分类一起解析只会互相排队；最多两路并行补齐首页。
    let cursor = 0;
    const worker = async (): Promise<void> => {
      while (cursor < blocks.length) {
        const block = blocks[cursor++];
        await loadBlock(block);
      }
    };
    await Promise.all([worker(), worker()]);
    if (completed === 0 && failed) throw new Error(failureMessage);
    return blocks.filter((block: HomeBlockSection): boolean => block.books.length > 0);
  }
}
