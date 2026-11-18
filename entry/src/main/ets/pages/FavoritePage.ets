import { GeneralSettings } from '../model/GeneralSettings';
import { BookPresentation } from '../model/BookPresentation';
import { BookEditSheet } from '../components/BookEditSheet';
import { WidgetUpdater } from '../service/WidgetUpdater';
import { AVSessionService } from '../service/AVSessionService';
import { ImmersiveCircleButton } from '../components/ImmersiveCircleButton';
import { BookCoverPolicy } from '../utils/BookCoverPolicy';
import { AdaptiveLayout } from '../utils/AdaptiveLayout';
import { PlatformCompat } from '../utils/PlatformCompat';
import { HdsCompat } from '../utils/HdsCompat';
import { CapsuleSegmentButtonV2, ColorMetrics, LengthMetrics, SegmentButtonV2Items } from '@kit.ArkUI';
import { common, ApplicationStateChangeCallback } from '@kit.AbilityKit';
import { emitter } from '@kit.BasicServicesKit';
import {
  HdsNavigation, HdsNavigationTitleMode, BottomBuilderParams, BuilderOptions, TitleBarContentOptions
} from '@kit.UIDesignKit';
import {
  AppColor,
  AppRadius,
  AppSpace,
  AppFont,
  AppMaterial,
  HomeTheme,
  AppTheme
} from '../theme/Theme';
import { CoverDecoration } from '../components/CoverDecoration';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { Book, Chapter } from '../model/Book';
import { TocItem } from '../model/BookSource';
import { BookSourceService } from '../service/BookSourceService';
import { DataService } from '../service/DataService';
import { ChapterCacheService } from '../service/ChapterCacheService';
import { OnlineTextContentCache } from '../service/text/OnlineTextContentCache';
import { PreferenceService, PlayHistoryItem, EVT_FAVORITES_CHANGED, EVT_SHELF_SOURCE_VISIBILITY_CHANGED } from '../service/PreferenceService';
import { SourceDataService } from '../service/SourceDataService';
import { AudioService, EVT_HISTORY_UPDATED } from '../service/AudioService';
import { StatsService } from '../service/StatsService';
import { TextToSpeechService } from '../service/text/TextToSpeechService';
import { PlaybackStore } from '../service/PlaybackStore';
import { SearchCache } from '../utils/SearchCache';
import { WindowUtils } from '../utils/WindowUtils';
import { BookDataSource } from '../utils/BookDataSource';
import { CoverImage } from '../components/CoverImage';
import { ShelfUpdateService, ShelfUpdateReport, BookUpdateInfo } from '../service/ShelfUpdateService';
import { DownloadService } from '../service/DownloadService';
import { TextReaderRouteParams, TextReadingPosition } from '../model/TextReading';
import { TextReadingProgressService, EVT_TEXT_READING_PROGRESS_CHANGED } from '../service/text/TextReadingProgressService';

const BOOKSHELF_COVER_RATIO: number = 0.75;
const MINI_TITLE_BAR_HEIGHT: number = 56;
const SHELF_FILTER_TOP_OFFSET: number = MINI_TITLE_BAR_HEIGHT;
const SHELF_FILTER_ROW_HEIGHT: number = 48;
const SHELF_SEARCH_ROW_HEIGHT: number = 50;
const SHELF_CONTENT_GAP: number = 12;

function cloneChapter(ch: Chapter): Chapter {
  return {
    id: ch.id,
    index: ch.index,
    title: ch.title,
    duration: ch.duration,
    source: {
      type: ch.source.type,
      value: ch.source.value
    },
    originSourceValue: ch.originSourceValue,
    variables: ch.variables
  };
}

function cloneBook(book: Book): Book {
  const variables: Record<string, string> | undefined = book.variables ? {} : undefined;
  if (book.variables && variables) {
    for (const k of Object.keys(book.variables)) {
      variables[k] = book.variables[k];
    }
  }
  return {
    id: book.id,
    contentType: book.contentType,
    title: book.title,
    author: book.author,
    narrator: book.narrator,
    cover: book.cover,
      coverFromDetail: book.coverFromDetail,
      coverFallback: book.coverFallback,
    category: book.category,
    intro: book.intro,
    wordCount: book.wordCount,
    latestChapterTitle: book.latestChapterTitle,
    updateTime: book.updateTime,
    totalDuration: book.totalDuration,
    chapterCount: book.chapterCount,
    rating: book.rating,
    tags: book.tags ? book.tags.slice() : [],
    chapters: book.chapters ? book.chapters.map((ch: Chapter): Chapter => cloneChapter(ch)) : [],
    bookUrl: book.bookUrl,
    sourceUrl: book.sourceUrl,
    variables,
    skipIntro: book.skipIntro,
    skipOutro: book.skipOutro,
    completed: book.completed
  };
}

function chaptersChanged(oldChapters: Chapter[], newChapters: Chapter[]): boolean {
  if (oldChapters.length !== newChapters.length) return true;
  for (let i = 0; i < newChapters.length; i++) {
    const oldChapter = oldChapters[i];
    const newChapter = newChapters[i];
    if (!oldChapter || oldChapter.title !== newChapter.title ||
      oldChapter.originSourceValue !== newChapter.originSourceValue ||
      oldChapter.source.value !== newChapter.source.value ||
      JSON.stringify(oldChapter.variables) !== JSON.stringify(newChapter.variables)) {
      return true;
    }
  }
  return false;
}

@ComponentV2
export struct FavoritePage {
  @Local bookColumns: number = 3;
  @Local favoriteBooks: Book[] = [];
  @Local showShelfSource: boolean = GeneralSettings.current.showShelfSource;
  @Local sourceNames: Map<string, string> = new Map();
  @Local historyMap: Record<string, PlayHistoryItem> = {};
  @Local chapterIdxMap: Record<string, number> = {};
  @Local loading: boolean = true;
  @Local isRefreshing: boolean = false;
  @Local resolvingTocId: string = '';
  @Local refreshProgress: string = '';
  @Local checkingUpdates: boolean = false;
  @Local updateReport: ShelfUpdateReport = new ShelfUpdateReport();
  private alive: boolean = false;
  private foreground: boolean = true;
  private applicationState: ApplicationStateChangeCallback = {
    onApplicationForeground: (): void => {
      this.foreground = true;
      if (this.visible && !this.loading) this.scheduleAutoUpdate();
    },
    onApplicationBackground: (): void => { this.foreground = false; this.cancelAutoUpdate(); }
  };
  @Local missingFavoriteCount: number = 0;
  @Local viewMode: number = 0; // 0=网格，1=列表
  private viewModeRevision: number = 0;
  private viewModeSaveTask: Promise<void> = Promise.resolve();
  @Local shelfFilter: number = 0; // 0=全部, 1=有声书, 2=电子书, 3=漫画
  @Local shelfKeyword: string = '';
  private shelfSearchController: SearchController = new SearchController();
  @Local topSafeVp: number = WindowUtils.getStatusBarHeightVp();
  @Local textProgressMap: Map<string, TextReadingPosition> = new Map();
  @Param visible: boolean = false;
  @Local showBookActions: boolean = false;
  @Local pinnedBookIds: Set<string> = new Set();
  @Local removingBook: boolean = false;
  private favoriteIdsByBookId: Map<string, string[]> = new Map();
  private favoritesLoadSerial: number = 0;
  private initialLoadTimer: number = -1;
  private initialLoadRunning: boolean = false;
  private autoUpdateTimer: number = -1;
  private pendingRemoval: Book | null = null;
  private pendingDownloadBook: Book | null = null;
  @Local showBookEditor: boolean = false;
  @Local editingBook: Book | null = null;
  @Local shelfGroups: string[] = [];
  private pendingDeleteFiles: boolean = false;

  @Param navStack: NavPathStack = new NavPathStack();
  @Event onBookTap: (id: string) => void = () => {};
  @Event onScrollerReady: (scroller: Scroller) => void = () => {};
  @Event onBackHandlerChange: (handler: (() => boolean) | undefined) => void = () => {};

  private context: common.UIAbilityContext | null = null;
  private listScroller: Scroller = new Scroller();
  private bookDataSource: BookDataSource = new BookDataSource();
  private readonly shelfTitleBarBuilder: CustomBuilder = (): void => this.buildShelfTitleBar();
  private readonly shelfFilterBuilder: CustomBuilder = (): void => this.buildShelfFilter();
  private historyUpdatedHandler: (e: emitter.EventData) => void = (e) => this.onHistoryUpdated(e);
  /** 加入/移出书架后重新拉书清单。 */
  private favoritesChangedHandler: () => void = () => {
    if (!this.removingBook) this.loadFavorites();
  };
  private shelfSourceVisibilityHandler: () => void = () => this.syncShelfSourceVisibility();
  private textProgressLoadSerial: number = 0;
  private textProgressChangedHandler: () => void = () => { this.refreshTextProgress(); };
  private safeAreaChangedHandler: (topVp: number, bottomVp: number) => void =
    (topVp: number, _bottomVp: number): void => { this.topSafeVp = topVp; };

  @Computed
  get shelfAudioCount(): number {
    return this.favoriteBooks.filter((book: Book): boolean => book.contentType !== 'text').length;
  }

  @Computed
  get shelfTextCount(): number {
    return this.favoriteBooks.filter((book: Book): boolean => book.contentType === 'text').length;
  }

  @Computed
  get shelfFilterItems(): SegmentButtonV2Items {
    return new SegmentButtonV2Items([
      { text: this.shelfFilterText($r('app.string.shelf_filter_all_count'), this.favoriteBooks.length) },
      { text: this.shelfFilterText($r('app.string.shelf_filter_audio_count'), this.shelfAudioCount) },
      { text: this.shelfFilterText($r('app.string.shelf_filter_text_count'), this.shelfTextCount) }
    ]);
  }

  private shelfFilterText(label: Resource, count: number): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(label.id, count) ?? count.toString();
  }

  private getChapterCount(book: Book): number {
    return book.chapters && book.chapters.length > 0 ? book.chapters.length : (book.chapterCount || 0);
  }

  /** 汇总每本书的最新集数：优先章节匹配，失败时使用独立进度中已落盘的章节序号。 */
  private async buildChapterIndexMap(books: Book[], historyMap: Record<string, PlayHistoryItem>):
    Promise<Record<string, number>> {
    const idxMap: Record<string, number> = {};
    for (const book of books) {
      const chapterCount = this.getChapterCount(book);
      if (chapterCount <= 0) continue;

      const progress = await PreferenceService.getProgress(book.id);
      const history = historyMap[book.id];
      let idx = -1;
      if (progress && book.chapters && book.chapters.length > 0) {
        idx = DataService.resolveChapterIndex(book, progress.chapterId, progress.chapterTitle);
      }
      if (idx < 0 && progress && progress.chapterIndex >= 0 && progress.chapterIndex < chapterCount) {
        idx = progress.chapterIndex;
      }
      if (idx < 0 && history && book.chapters && book.chapters.length > 0) {
        idx = DataService.resolveChapterIndex(book, history.chapterId, history.chapterTitle);
      }
      if (idx >= 0 && idx < chapterCount) idxMap[book.id] = idx;
    }
    return idxMap;
  }

  private syncFavoriteBook(updatedBook: Book): void {
    const books = this.favoriteBooks.map((book: Book): Book => book.id === updatedBook.id ? updatedBook : book);
    this.favoriteBooks = books;
    this.bookDataSource.setBooks(this.filteredBooks(books));
  }

  aboutToAppear(): void {
    this.alive = true;
    WindowUtils.addSafeAreaListener(this.safeAreaChangedHandler);
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try { this.context.getApplicationContext().on('applicationStateChange', this.applicationState); } catch (_error) {}
    ShelfUpdateService.lastReport(this.context).then((report: ShelfUpdateReport): void => {
      if (this.alive && this.updateReport.checkedAt < report.checkedAt) this.applyUpdateReport(report);
    });
    this.scheduleInitialLoad();
    const viewRevision: number = this.viewModeRevision;
    PreferenceService.getShelfViewMode().then((mode: number): void => {
      if (this.alive && viewRevision === this.viewModeRevision) this.viewMode = mode;
    }).catch((): void => {});
    emitter.on(EVT_HISTORY_UPDATED, this.historyUpdatedHandler);
    emitter.on(EVT_FAVORITES_CHANGED, this.favoritesChangedHandler);
    emitter.on(EVT_SHELF_SOURCE_VISIBILITY_CHANGED, this.shelfSourceVisibilityHandler);
    this.syncShelfSourceVisibility();
    emitter.on(EVT_TEXT_READING_PROGRESS_CHANGED, this.textProgressChangedHandler);
    this.onScrollerReady(this.listScroller);
  }

  aboutToDisappear(): void {
    this.alive = false;
    if (this.initialLoadTimer !== -1) clearTimeout(this.initialLoadTimer);
    this.initialLoadTimer = -1;
    this.cancelAutoUpdate();
    try { this.context?.getApplicationContext().off('applicationStateChange', this.applicationState); } catch (_error) {}
    WindowUtils.removeSafeAreaListener(this.safeAreaChangedHandler);
    this.favoritesLoadSerial++;
    emitter.off(EVT_HISTORY_UPDATED, this.historyUpdatedHandler);
    emitter.off(EVT_FAVORITES_CHANGED, this.favoritesChangedHandler);
    emitter.off(EVT_SHELF_SOURCE_VISIBILITY_CHANGED, this.shelfSourceVisibilityHandler);
    emitter.off(EVT_TEXT_READING_PROGRESS_CHANGED, this.textProgressChangedHandler);
    this.textProgressLoadSerial++;
  }

  @Monitor('visible')
  onVisibleChange(): void {
    if (this.visible) {
      this.syncShelfSourceVisibility();
      if (this.loading) this.scheduleInitialLoad();
      else this.scheduleAutoUpdate();
    }
    if (!this.visible) this.cancelAutoUpdate();
  }

  /** Appear 与 visible 监控共用入口；下个任务加载缓存，不再额外等待切页动画。 */
  private scheduleInitialLoad(): void {
    if (!this.alive || this.initialLoadTimer !== -1 || this.initialLoadRunning) return;
    this.initialLoadTimer = setTimeout((): void => {
      this.initialLoadTimer = -1;
      if (!this.alive || !this.loading) return;
      this.initialLoadRunning = true;
      this.loadFavorites().catch((): void => {
        // 保留 loading，下一次进入书架可重试，不提交空书单。
      }).finally((): void => { this.initialLoadRunning = false; });
    }, 0);
  }

  private cancelAutoUpdate(): void {
    if (this.autoUpdateTimer !== -1) clearTimeout(this.autoUpdateTimer);
    this.autoUpdateTimer = -1;
  }

  private scheduleAutoUpdate(): void {
    this.cancelAutoUpdate();
    if (!this.alive || !this.visible || !this.foreground || this.loading || this.checkingUpdates ||
      !ShelfUpdateService.shouldAutoCheck()) return;
    this.autoUpdateTimer = setTimeout((): void => {
      this.autoUpdateTimer = -1;
      if (this.alive && this.visible && this.foreground) this.refreshOnlineBooks(true);
    }, 400);
  }

  private syncShelfSourceVisibility(): void {
    const enabled: boolean = GeneralSettings.current.showShelfSource;
    if (this.showShelfSource === enabled) return;
    this.showShelfSource = enabled;
    this.bookDataSource.setBooks(this.filteredBooks(this.favoriteBooks));
  }

  /** 收到播放进度更新事件:只重算历史相关 map,不重拉书清单,避免列表抖动 */
  private async onHistoryUpdated(_e: emitter.EventData): Promise<void> {
    if (!this.context || this.favoriteBooks.length === 0) return;
    const history = await PreferenceService.getHistory();
    const map: Record<string, PlayHistoryItem> = {};
    for (const item of history) {
      if (!map[item.bookId]) {
        map[item.bookId] = item;
      }
    }
    const idxMap = await this.buildChapterIndexMap(this.favoriteBooks, map);
    this.historyMap = map;
    this.chapterIdxMap = idxMap;
  }

  async loadFavorites(): Promise<void> {
    if (!this.context) return;
    if (this.initialLoadTimer !== -1) clearTimeout(this.initialLoadTimer);
    this.initialLoadTimer = -1;
    const serial = ++this.favoritesLoadSerial;
    this.shelfGroups = BookPresentation.groups.slice();
    const ids = await PreferenceService.getShelfFavorites();
    const pinnedIds = new Set(await PreferenceService.getPinnedFavorites());
    const allBooks = await DataService.getBooks(this.context);
    const byId = new Map<string, Book>();
    for (const book of allBooks) {
      if (book && book.id) {
        byId.set(book.id, book);
      }
    }

    const history = await PreferenceService.getHistory();
    const map: Record<string, PlayHistoryItem> = {};
    for (const item of history) {
      if (!map[item.bookId]) {
        map[item.bookId] = item;
      }
    }

    const lastPlayed = await PreferenceService.getLastPlayed();
    const books: Book[] = [];
    const aliases: Map<string, string[]> = new Map();
    let missingCount = 0;
    for (const id of ids) {
      const book = byId.get(id);
      if (book) {
        if (!aliases.has(book.id)) books.push(book);
        aliases.set(book.id, (aliases.get(book.id) ?? []).concat(id));
        continue;
      }
      const progress = await PreferenceService.getProgress(id);
      const chapterTitle = map[id]?.chapterTitle ?? progress?.chapterTitle ??
        (lastPlayed?.bookId === id ? (lastPlayed.chapterTitle ?? '') : '');
      const chapterId = map[id]?.chapterId ?? progress?.chapterId ??
        (lastPlayed?.bookId === id ? lastPlayed.chapterId : '');
      const chapterIndex = progress?.chapterIndex ?? this.parseLegacyChapterIndex(chapterId);
      const alias = this.findFavoriteAlias(id, chapterTitle, chapterIndex, allBooks);
      if (alias) {
        if (!aliases.has(alias.id)) books.push(alias);
        aliases.set(alias.id, (aliases.get(alias.id) ?? []).concat(id));
        continue;
      }
      books.push(this.createMissingFavoriteBook(id, chapterTitle));
      aliases.set(id, [id]);
      missingCount++;
    }
    // 切 Tab 只解析书架实际引用的来源，避免为名称标签重读全部导入规则。
    // 禁用源仍可解析，删除源也不影响收藏保留与显示。
    this.loadSourceNames(books, serial);

    // 修复历史缓存中的双倍章节:按 title + index 去重(title 稳定,不会被播放覆盖)
    let scanStartedAt: number = Date.now();
    let scannedChapters: number = 0;
    for (const b of books) {
      if (serial !== this.favoritesLoadSerial || !this.alive) return;
      if (this.isMissingCachedBook(b)) continue;
      if (b.chapters && b.chapters.length > 0) {
        const seen = new Set<string>();
        const unique: Chapter[] = [];
        for (const ch of b.chapters) {
          // await 已完成的 Promise 不会让出 UI 帧；大目录按时间预算分段扫描。
          if (++scannedChapters % 256 === 0 && Date.now() - scanStartedAt >= 8) {
            await new Promise<void>((resolve): void => { setTimeout(resolve, 0); });
            if (serial !== this.favoritesLoadSerial || !this.alive) return;
            scanStartedAt = Date.now();
          }
          // 去重键用章节页 URL(唯一且稳定):originSourceValue 不会被播放期解析覆盖。
          // 旧实现用 title 去重会误删"同名不同章"(网文源极常见,如多章都叫"正文"),
          // 导致刷新拿到的新章节数(如 758)被吞回旧值(472)。
          const key = ch.originSourceValue || ch.source.value || ch.title;
          if (seen.has(key)) continue;
          seen.add(key);
          unique.push(ch);
        }
        if (unique.length !== b.chapters.length) {
          b.chapters = unique;
          b.chapterCount = unique.length;
          // 持久化修正后的数据
          await DataService.upsertCachedBook(b);
        } else if (b.chapterCount !== b.chapters.length) {
          b.chapterCount = b.chapters.length;
          await DataService.upsertCachedBook(b);
        }
      }
    }

    // 预算每本书的最新章节序号，避免 build / click 反复解析，也兼容章节 ID 已变化的旧进度。
    const idxMap = await this.buildChapterIndexMap(books, map);
    if (serial !== this.favoritesLoadSerial) return;
    this.missingFavoriteCount = missingCount;
    this.pinnedBookIds = new Set(books.filter((book: Book): boolean =>
      (aliases.get(book.id) ?? [book.id]).some((id: string): boolean => pinnedIds.has(id)))
      .map((book: Book): string => book.id));
    this.favoriteIdsByBookId = aliases;
    this.favoriteBooks = books;
    await this.refreshTextProgress();
    if (serial !== this.favoritesLoadSerial) return;
    this.bookDataSource.setBooks(this.filteredBooks(books));
    this.historyMap = map;
    this.chapterIdxMap = idxMap;
    this.loading = false;
    this.scheduleAutoUpdate();
  }

  /** 阅读器覆盖书架时 Tab 不变；由保存事件更新进度，避免重新加载书单。 */
  private sourceNamesRevision: number = -1;

  private async loadSourceNames(books: Book[], serial: number): Promise<void> {
    const revision = SourceDataService.getInvalidationCounter();
    const names: Map<string, string> = revision === this.sourceNamesRevision ? new Map(this.sourceNames) : new Map();
    const urls = Array.from(new Set(books.map((book: Book): string => book.sourceUrl).filter((url: string): boolean => !!url)));
    for (const url of urls) {
      if (serial !== this.favoritesLoadSerial || !this.alive) return;
      if (names.has(url)) continue;
      try {
        const source = await SourceDataService.getSourceByUrl(url);
        if (source) names.set(url, source.bookSourceName);
      } catch (_error) {}
      await new Promise<void>((resolve): void => { setTimeout(resolve, 0); });
    }
    if (serial === this.favoritesLoadSerial && this.alive && revision === SourceDataService.getInvalidationCounter()) {
      this.sourceNames = names;
      this.sourceNamesRevision = revision;
    }
  }

  private async refreshTextProgress(): Promise<void> {
    const context = this.context;
    if (context === null) return;
    const serial = ++this.textProgressLoadSerial;
    const textProgress = new Map<string, TextReadingPosition>();
    try {
      for (const book of this.favoriteBooks) {
        if (book.contentType !== 'text') continue;
        const position = await TextReadingProgressService.get(context, book.id);
        if (position) textProgress.set(book.id, position);
      }
      if (serial === this.textProgressLoadSerial) this.textProgressMap = textProgress;
    } catch (_e) {
      // 读取失败保留已有展示，后续保存或刷新时重试。
    }
  }

  private createMissingFavoriteBook(id: string, chapterTitle: string): Book {
    const inferredTitle = this.legacyBookNameFromChapterTitle(chapterTitle);
    const isText = id.startsWith('search_text_') || id.startsWith('home_text_');
    return {
      id,
      contentType: isText ? 'text' : 'audio',
      title: inferredTitle || (isText ? '电子书缓存缺失' : '有声书缓存缺失'),
      author: '收藏记录仍在',
      narrator: '',
      cover: '',
      category: isText ? '电子书' : '有声书',
      intro: '',
      totalDuration: 0,
      chapterCount: 0,
      rating: 0,
      tags: ['cache_missing'],
      chapters: [],
      bookUrl: '',
      sourceUrl: ''
    };
  }

  private createFavoriteAliasBook(id: string, source: Book): Book {
    const book = cloneBook(source);
    book.id = id;
    const tags = book.tags ? book.tags.filter((tag: string): boolean =>
      tag !== 'cache_missing' && tag !== 'cache_alias') : [];
    tags.push('cache_alias');
    book.tags = tags;
    book.chapters = book.chapters ? book.chapters.map((ch: Chapter, idx: number): Chapter => {
      const next = cloneChapter(ch);
      next.id = `${id}-c${idx}`;
      next.index = idx + 1;
      return next;
    }) : [];
    book.chapterCount = book.chapters.length > 0 ? book.chapters.length : book.chapterCount;
    return book;
  }

  private isMissingCachedBook(book: Book): boolean {
    return book.tags ? book.tags.includes('cache_missing') : false;
  }

  private isFavoriteAliasBook(book: Book): boolean {
    return book.tags ? book.tags.includes('cache_alias') : false;
  }

  private legacyBookNameFromChapterTitle(title: string): string {
    const t = title.trim();
    if (!t || t.startsWith('第') || /^[0-9０-９]/.test(t)) return '';
    const space = t.search(/[\s　]/);
    if (space <= 0) return '';
    const name = t.substring(0, space).trim();
    if (!name || name.startsWith('第') || /^[0-9０-９]/.test(name)) return '';
    return name;
  }

  private normalizeRecoverName(name: string): string {
    return name
      .replace(/[《》【】\[\]（）()：:，,。.\s　]/g, '')
      .trim();
  }

  private parseLegacyChapterIndex(chapterId: string): number {
    const m = chapterId.match(/-c(\d+)$/);
    if (!m) return -1;
    const idx = parseInt(m[1], 10);
    return isNaN(idx) ? -1 : idx;
  }

  /**
   * 只做运行期别名,不写 favorite_book_ids。
   * 规则故意保守:旧标题里能取到书名,且缓存池里只有一本完整标题精确匹配的有声书,才用于展示和打开。
   */
  private findFavoriteAlias(oldId: string, chapterTitle: string, chapterIndex: number, books: Book[]): Book | null {
    const oldIsAudio = oldId.startsWith('search_audio_') || oldId.startsWith('home_audio_');
    if (!oldIsAudio) return null;

    const name = this.normalizeRecoverName(this.legacyBookNameFromChapterTitle(chapterTitle));
    if (!name) return null;
    const candidates: Book[] = [];
    for (const book of books) {
      if (this.normalizeRecoverName(book.title) !== name) continue;
      if (chapterIndex >= 0 && book.chapters && chapterIndex >= book.chapters.length) continue;
      candidates.push(book);
    }
    if (candidates.length !== 1) return null;
    return this.createFavoriteAliasBook(oldId, candidates[0]);
  }

  /** 每日自动检查静默执行；手动下拉与自动检查共用任务，避免重复请求。 */
  private async refreshOnlineBooks(silent: boolean = false): Promise<void> {
    if (!this.context || !this.alive || this.checkingUpdates) return;
    if (silent && !ShelfUpdateService.shouldAutoCheck()) return;
    if (silent && (!this.visible || !this.foreground || this.removingBook)) return;
    const onlineBooks = this.favoriteBooks.filter((book: Book): boolean =>
      !this.isMissingCachedBook(book) && !this.isFavoriteAliasBook(book) &&
      !book.id.startsWith('import_') && !!book.bookUrl && !!book.sourceUrl);
    if (onlineBooks.length === 0) {
      if (!silent && this.alive) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: $r('app.string.shelf_update_book_count', 0) });
        } catch (_error) {}
      }
      return;
    }
    this.checkingUpdates = true;
    try {
      const report = await ShelfUpdateService.run(this.context, silent,
        (): Promise<ShelfUpdateReport> => this.checkOnlineBooks(onlineBooks));
      if (report !== undefined && this.alive) {
        this.applyUpdateReport(report);
        // checkOnlineBooks 已逐本提交变化；无变化不重载，有变化只校正进度映射。
        if (report.updatedCount > 0) await this.onHistoryUpdated({});
        if (!silent && this.visible && this.foreground) {
          try {
            this.getUIContext().getPromptAction().showToast({
              message: report.updatedCount > 0
                ? $r('app.string.shelf_update_book_count', report.updatedCount)
                : $r('app.string.shelf_update_checked_count', report.checkedCount)
            });
          } catch (_error) {}
        }
      }
    } catch (error) {
      console.warn(`[FavoritePage] update failed: ${error}`);
      if (!silent && this.alive) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: $r('app.string.shelf_update_error') });
        } catch (_error) {}
      }
    } finally {
      if (this.alive) {
        this.checkingUpdates = false;
        this.isRefreshing = false;
        this.refreshProgress = '';
      }
    }
  }

  private applyUpdateReport(report: ShelfUpdateReport): void {
    this.updateReport = report;
  }

  private async checkOnlineBooks(onlineBooks: Book[]): Promise<ShelfUpdateReport> {
    let updated = 0;
    let failed = 0;
    const updatedBooks: BookUpdateInfo[] = [];
    let completed = 0;
    const refreshBook = async (book: Book): Promise<void> => {
      try {
        const source = await SourceDataService.getSourceByUrl(book.sourceUrl);
        if (!source) {
          failed++;
          return;
        }
        const nextBook = cloneBook(book);
        // 1. 获取最新书籍信息
        const bookInfo = await BookSourceService.getBookInfo(source, nextBook.bookUrl, nextBook.variables);
        let hasChange = false;
        let chapterChanged = false;
        const oldCount = this.getChapterCount(book);
        let newCount = oldCount;
        if (bookInfo) {
          // 更新封面/简介/作者等元数据
          if (bookInfo.coverUrl && (bookInfo.coverUrl !== nextBook.cover || !nextBook.coverFromDetail)) {
            BookCoverPolicy.setDetail(nextBook, bookInfo.coverUrl);
            hasChange = true;
          }
          if (bookInfo.intro && bookInfo.intro !== nextBook.intro) {
            nextBook.intro = bookInfo.intro;
            hasChange = true;
          }
          if (bookInfo.author && bookInfo.author !== nextBook.author) {
            nextBook.author = bookInfo.author;
            hasChange = true;
          }
          // 合并变量
          if (bookInfo.wordCount && bookInfo.wordCount !== nextBook.wordCount) {
            nextBook.wordCount = bookInfo.wordCount;
            hasChange = true;
          }
          if (bookInfo.lastChapter && bookInfo.lastChapter !== nextBook.latestChapterTitle) {
            nextBook.latestChapterTitle = bookInfo.lastChapter;
            hasChange = true;
          }
          if (bookInfo.updateTime && bookInfo.updateTime !== nextBook.updateTime) {
            nextBook.updateTime = bookInfo.updateTime;
            hasChange = true;
          }
          if (bookInfo.variables) {
            if (!nextBook.variables) nextBook.variables = {};
            for (const k of Object.keys(bookInfo.variables)) {
              nextBook.variables[k] = bookInfo.variables[k];
            }
          }
        }
        // 2. 获取最新章节列表
        const mergedVars: Record<string, string> = {};
        if (nextBook.variables) {
          for (const k of Object.keys(nextBook.variables)) mergedVars[k] = nextBook.variables[k];
        }
        if (bookInfo?.variables) {
          for (const k of Object.keys(bookInfo.variables)) mergedVars[k] = bookInfo.variables[k];
        }
        const tocUrl = bookInfo?.tocUrl || nextBook.bookUrl;
        const tocItems = await BookSourceService.getBookToc(source, tocUrl, mergedVars, nextBook.title);
        if (tocItems.length > 0) {
          const chapters = tocItems.map((item: TocItem, i: number): Chapter => ({
            id: `${nextBook.id}-c${i}`,
            index: i + 1,
            title: item.name,
            duration: item.duration || 0,
            source: { type: 'url', value: item.url },
            originSourceValue: item.url,
            variables: item.variables
          }));
          if (chaptersChanged(nextBook.chapters || [], chapters)) {
            hasChange = true;
          }
          nextBook.chapters = chapters;
          nextBook.chapterCount = chapters.length;
          newCount = nextBook.chapterCount;
          chapterChanged = newCount > oldCount;
        } else if (nextBook.chapters && nextBook.chapters.length > 0 && nextBook.chapterCount !== nextBook.chapters.length) {
          nextBook.chapterCount = nextBook.chapters.length;
          newCount = nextBook.chapterCount;
          hasChange = true;
        }
        if (hasChange) {
          await DataService.upsertCachedBook(nextBook);
          SearchCache.put(nextBook);
          if (this.alive) this.syncFavoriteBook(nextBook);
          updated++;
          if (chapterChanged) {
            const updateInfo = new BookUpdateInfo();
            updateInfo.bookId = nextBook.id;
            updateInfo.title = nextBook.title;
            updateInfo.cover = nextBook.cover;
            updateInfo.oldCount = oldCount;
            updateInfo.newCount = newCount;
            updateInfo.isText = nextBook.contentType === 'text';
            updateInfo.latestChapter = nextBook.latestChapterTitle || nextBook.chapters?.[newCount - 1]?.title || '';
            updatedBooks.push(updateInfo);
          }
        }
      } catch (_e) {
        failed++;
      } finally {
        completed++;
        if (this.alive && this.isRefreshing) {
          try {
            this.refreshProgress = this.getUIContext().getHostContext()?.resourceManager.getStringSync(
              $r('app.string.shelf_update_progress').id, completed, onlineBooks.length) ?? '';
          } catch (_error) {}
        }
      }
    };
    let cursor = 0;
    const worker = async (): Promise<void> => {
      while (cursor < onlineBooks.length) await refreshBook(onlineBooks[cursor++]);
    };
    await Promise.all([worker(), worker(), worker()]);
    const report = new ShelfUpdateReport();
    report.checkedAt = Date.now();
    report.checkedCount = onlineBooks.length;
    report.updatedCount = updated;
    report.failedCount = failed;
    report.entries = updatedBooks.sort((a: BookUpdateInfo, b: BookUpdateInfo): number =>
      (b.newCount - b.oldCount) - (a.newCount - a.oldCount));
    return report;
  }

  private getProgressText(book: Book): string {
    if (this.isMissingCachedBook(book)) {
      return '缓存缺失 · 重新搜索后加入';
    }
    if (book.contentType === 'comic') {
      const chapterCount = this.getChapterCount(book);
      return chapterCount > 0 ? `共${chapterCount}话 · 暂不支持漫画` : '暂不支持漫画';
    }
    if (book.contentType === 'text') {
      const position = this.textProgressMap.get(book.id);
      const chapterCount = this.getChapterCount(book);
      if (position && chapterCount > 0) {
        return `${Math.min(position.resourceIndex + 1, chapterCount)}/${chapterCount} 章`;
      }
      return chapterCount > 0 ? `共${chapterCount}章` : '未开始阅读';
    }
    const unit = '集';
    const chapterCount = this.getChapterCount(book);
    if (chapterCount > 0) {
      const idx = this.chapterIdxMap[book.id];
      if (idx !== undefined && idx >= 0) {
        return `${idx + 1}/${chapterCount} ${unit}`;
      }
      return `共${chapterCount}${unit}`;
    }
    return book.author || '';
  }

  private toggleViewMode(): void {
    this.viewModeRevision++;
    this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
      this.viewMode = this.viewMode === 0 ? 1 : 0;
    });
    const mode: number = this.viewMode;
    this.viewModeSaveTask = this.viewModeSaveTask.then((): Promise<void> =>
      PreferenceService.setShelfViewMode(mode)).catch((): void => {});
  }

  private shelfHeaderHeight(): number {
    return SHELF_FILTER_ROW_HEIGHT + SHELF_SEARCH_ROW_HEIGHT;
  }

  @Computed
  get shelfTitleBarContent(): TitleBarContentOptions {
    const bottom: BottomBuilderParams = {
      builder: this.shelfFilterBuilder,
      height: this.shelfHeaderHeight()
    };
    const content: TitleBarContentOptions = {
      stackBuilder: this.shelfTitleBarBuilder,
      bottomBuilder: bottom
    };
    if (PlatformCompat.supports(26)) {
      const titleBuilder: BuilderOptions = { builder: this.shelfTitleBarBuilder, updated: false };
      const filterBuilder: BuilderOptions = { builder: this.shelfFilterBuilder, updated: false };
      content.stackBuilderContent = titleBuilder;
      bottom.builderContent = filterBuilder;
    }
    return content;
  }

  private filteredBooks(books: Book[]): Book[] {
    const keyword = this.shelfKeyword.trim().toLocaleLowerCase();
    return books.filter((book: Book): boolean => {
      if (this.shelfFilter === 1 && book.contentType === 'text') return false;
      if (this.shelfFilter === 2 && book.contentType !== 'text') return false;
      return keyword.length === 0 || [book.title, book.author, book.narrator]
        .some((value: string): boolean => (value || '').toLocaleLowerCase().includes(keyword));
    });
  }

  private selectShelfFilter(index: number): void {
    if (this.removingBook) return;
    if (index < 0 || index > 2 || this.shelfFilter === index) return;
    this.shelfFilter = index;
    this.bookDataSource.setBooks(this.filteredBooks(this.favoriteBooks));
  }

  private handleBookTap(book: Book): void {
    if (this.removingBook) return;
    const onPop = (): void => { this.loadFavorites(); };
    if (this.isMissingCachedBook(book)) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '这本书的缓存快照缺失，请重新搜索后加入书架' });
      } catch (_e) { /* ignore */ }
      return;
    }
    SearchCache.put(book);
    if (book.contentType === 'comic') {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '暂不支持漫画' });
      } catch (_e) { /* ignore */ }
      return;
    }
    if (book.contentType === 'text') {
      const params = TextReaderRouteParams.of(book.id);
      this.navStack.pushPathByName('reader', params, onPop);
      return;
    }
    if (book.sourceUrl && !this.sourceNames.has(book.sourceUrl)) {
      // 旧来源已删除时仍能进入播放器，通过现有换源入口继续收听。
      this.navStack.pushPathByName('player', book.id, onPop);
      return;
    }
    // 当前正在播这本书:不重新解析 URL,不带 chapter 参数,直接进 player 复用 live state。
    if (PlaybackStore.getInstance().isCurrentBook(book.id)) {
      this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
        this.navStack.pushPathByName('player', book.id, onPop, false);
      });
      return;
    }
    // 直接用已缓存的 historyMap,避免每次点击都 IO
    const history = this.historyMap[book.id];
    // 没有进度 → 详情页让用户选章节
    if (!history) {
      this.navStack.pushPathByName('detail', book.id, onPop);
      return;
    }
    // 章节列表尚未加载 → 在线书源主动拉 toc 后恢复进度;否则交给详情页
    if (!book.chapters || book.chapters.length === 0) {
      if (book.bookUrl && book.sourceUrl && !book.id.startsWith('import_')) {
        this.resumeOnlineWithToc(book, history, onPop);
      } else {
        this.navStack.pushPathByName('detail', book.id, onPop);
      }
      return;
    }
    // 有进度但定位不到对应章节(可能 TOC 重排) → 详情页
    const idx = this.chapterIdxMap[book.id];
    if (idx === undefined || idx < 0) {
      this.navStack.pushPathByName('detail', book.id, onPop);
      return;
    }
    SearchCache.put(book);
    // 用校正后的章节 id(idx 可能因 TOC 重排已被标题校正过),
    // 直接传 history.chapterId 会让播放器再按旧 id 找回错位置
    const resolved = book.chapters[idx];
    const params: Record<string, Object> = {
      'bookId': book.id as Object,
      'chapterId': resolved.id as Object,
      'progressMs': history.progressMs as Object
    };
    this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
      this.navStack.pushPathByName('player', params, onPop, false);
    });
  }

  /** 老收藏的在线书没缓存章节时,先拉 toc 再恢复进度;期间禁用重复点击 */
  private async resumeOnlineWithToc(book: Book, history: PlayHistoryItem, onPop: () => void): Promise<void> {
    if (this.resolvingTocId) return;
    this.resolvingTocId = book.id;
    try {
      // 1) 先用本地缓存的章节目录(sidecar):瞬时、无网络、不弹"加载章节"
      const localToc = await DataService.getChaptersForBook(book.id);
      if (localToc.length > 0) {
        book.chapters = localToc;
        book.chapterCount = localToc.length;
        const localIdx = DataService.resolveChapterIndex(book, history.chapterId, history.chapterTitle);
        if (localIdx >= 0) {
          this.chapterIdxMap[book.id] = localIdx;
          SearchCache.put(book);
          const resolvedLocal = book.chapters[localIdx];
          const localParams: Record<string, Object> = {
            'bookId': book.id as Object,
            'chapterId': resolvedLocal.id as Object,
            'progressMs': history.progressMs as Object
          };
          this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
            this.navStack.pushPathByName('player', localParams, onPop, false);
          });
          return;
        }
        // 本地目录命中但定位不到章节(可能已下架/重排)→ 落到下面联网重拉刷新
      }
      // 2) 本地没有 → 联网拉取(此时才提示"加载章节")
      try {
        this.getUIContext().getPromptAction().showToast({ message: '加载章节中...' });
      } catch (_e) { /* ignore */ }
      const source = await SourceDataService.getSourceByUrl(book.sourceUrl);
      if (!source) {
        this.navStack.pushPathByName('player', book.id, onPop);
        return;
      }
      let tocUrl = book.bookUrl;
      const bookInfo = await BookSourceService.getBookInfo(source, book.bookUrl, book.variables);
      const mergedVars: Record<string, string> = {};
      if (book.variables) {
        for (const k of Object.keys(book.variables)) mergedVars[k] = book.variables[k];
      }
      if (bookInfo?.variables) {
        for (const k of Object.keys(bookInfo.variables)) mergedVars[k] = bookInfo.variables[k];
      }
      if (bookInfo?.tocUrl) tocUrl = bookInfo.tocUrl;
      const tocItems = await BookSourceService.getBookToc(source, tocUrl, mergedVars, book.title);
      if (tocItems.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '章节加载失败' });
        this.navStack.pushPathByName('detail', book.id, onPop);
        return;
      }
      book.chapters = tocItems.map((item: TocItem, idx: number): Chapter => ({
        id: `${book.id}-c${idx}`,
        index: idx + 1,
        title: item.name,
        duration: item.duration || 0,
        source: { type: 'url', value: item.url },
        originSourceValue: item.url,
        variables: item.variables
      }));
      book.chapterCount = book.chapters.length;
      // 持久化新 toc,下次点击不用再拉
      await DataService.upsertCachedBook(book);
      SearchCache.put(book);
      const idx = DataService.resolveChapterIndex(book, history.chapterId, history.chapterTitle);
      if (idx < 0) {
        // 标题和 id 都定位不回去(章节可能已下架) → 交给详情页让用户选
        this.navStack.pushPathByName('detail', book.id, onPop);
        return;
      }
      this.chapterIdxMap[book.id] = idx;
      // 传校正后章节的 id:连载在头部插新章后,旧 -c{idx} 已指向别的章节,
      // 标题校正拿到正确 idx,再取它的当前 id 给播放器
      const resolved = book.chapters[idx];
      const params: Record<string, Object> = {
        'bookId': book.id as Object,
        'chapterId': resolved.id as Object,
        'progressMs': history.progressMs as Object
      };
    this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
      this.navStack.pushPathByName('player', params, onPop, false);
    });
    } catch (_e) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '章节加载失败' });
      } catch (_e2) { /* ignore */ }
      this.navStack.pushPathByName('detail', book.id, onPop);
    } finally {
      this.resolvingTocId = '';
    }
  }

  private async removeActionBook(book: Book, deleteFiles: boolean): Promise<void> {
    if (this.removingBook) return;
    if (this.showBookActions) {
      // 先让原生菜单完成退场，避免删除宿主节点后菜单遮罩和点击锁残留。
      this.pendingRemoval = book;
      this.pendingDeleteFiles = deleteFiles;
      return;
    }
    this.removingBook = true;
    try { await this.doRemove(book.id, deleteFiles); }
    finally { this.removingBook = false; this.showBookActions = false; }
  }

  private async downloadShelfBook(book: Book): Promise<void> {
    if (this.removingBook) return;
    if (book.contentType !== 'audio') {
      this.showShelfToast($r('app.string.shelf_download_audio_only'));
      return;
    }
    if (this.isMissingCachedBook(book) || (!book.id.startsWith('import_') && !book.bookUrl)) {
      this.showShelfToast($r('app.string.shelf_download_unavailable'));
      return;
    }
    try {
      const queued: number = book.id.startsWith('import_') || book.chapters.length > 0
        ? await DownloadService.getInstance().downloadBook(book)
        : await DownloadService.getInstance().downloadIncremental(book);
      this.showShelfToast(queued > 0 ? $r('app.string.download_queued_all') : $r('app.string.download_nothing_new'));
      if (queued > 0) {
        this.openDownloadManager();
      }
    } catch (_error) {
      this.showShelfToast($r('app.string.download_operation_failed'));
    }
  }

  private openDownloadManager(): void {
    const pathNames: Array<string> = this.navStack.getAllPathName();
    if (pathNames.length > 0 && pathNames[pathNames.length - 1] === 'downloads') {
      return;
    }
    this.navStack.pushPathByName('downloads', null);
  }

  private showShelfToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) { /* 页面离开时不提示。 */ }
  }

  private async deleteBookFilesAndRecords(bookId: string): Promise<void> {
    if (!this.context) return;
    const ids = new Set<string>(this.favoriteIdsByBookId.get(bookId) ?? []);
    ids.add(bookId);
    // 兼容同一有声书由首页/搜索产生的旧 id，避免未收藏页残留重复记录。
    for (const id of Array.from(ids)) {
      if (id.startsWith('search_audio_')) ids.add(id.replace('search_audio_', 'home_audio_'));
      if (id.startsWith('home_audio_')) ids.add(id.replace('home_audio_', 'search_audio_'));
    }
    const audio = AudioService.getInstance();
    const stopAudio = ids.has(PlaybackStore.getInstance().getCurrentBookId());
    const speech = TextToSpeechService.getInstance();
    if (ids.has(speech.state.bookId)) speech.stop();
    try {
      if (stopAudio) await audio.stopForClear();
      await DownloadService.getInstance().deleteBookDownload(bookId);
      if (bookId.startsWith('import_')) await DataService.removeImportedBook(bookId);
      for (const id of ids) {
        const storedBook = await DataService.getBookById(this.context, id);
        if (storedBook !== undefined && !id.startsWith('import_')) {
          ChapterCacheService.getInstance().clearBook(id, storedBook.chapters);
          await OnlineTextContentCache.removeBook(this.context, storedBook.sourceUrl ?? '', storedBook.bookUrl || id);
        }
        await PreferenceService.removeHistory(id);
        await PreferenceService.removeProgress(id);
        await TextReadingProgressService.remove(this.context, id);
      }
      await speech.removeSavedPositions(this.context, Array.from(ids));
      await StatsService.removeBookStats(Array.from(ids));
    } finally {
      if (stopAudio) audio.unfreezePersist();
    }
  }

  private bookMenuOptions(): ContextMenuOptions {
    const options: ContextMenuOptions = {
      preview: MenuPreviewMode.NONE,
      backgroundColor: AppMaterial.SheetBackground,
      backgroundBlurStyle: AppMaterial.SheetBlur,
      onAppear: (): void => { this.showBookActions = true; },
      onDisappear: (): void => {
        this.showBookActions = false;
        const downloadBook = this.pendingDownloadBook;
        this.pendingDownloadBook = null;
        if (downloadBook !== null) {
          this.downloadShelfBook(downloadBook).catch((): void => {});
        }
        const book = this.pendingRemoval;
        this.pendingRemoval = null;
        if (book !== null) this.removeActionBook(book, this.pendingDeleteFiles);
      }
    };
    if (PlatformCompat.immersiveMaterial) options.systemMaterial = AppMaterial.Sheet;
    return options;
  }

  @Builder
  bookActions(book: Book) {
    Menu() {
      if (book.contentType === 'audio') {
        MenuItem({ content: $r('app.string.book_detail_action_download') })
          .enabled(!this.removingBook && !this.isRefreshing)
          .onClick((): void => { this.pendingDownloadBook = book; })
      }
      MenuItem({ content: $r('app.string.shelf_edit_title') })
        .enabled(!this.removingBook && !this.isRefreshing)
        .onClick((): void => { this.editingBook = book; this.showBookEditor = true; })
      MenuItem({ content: $r('app.string.common_delete') })
        .contentFontColor($r('sys.color.ohos_id_color_warning'))
        .enabled(!this.removingBook)
        .onClick((): void => { this.removeActionBook(book, false); })
    }
  }

  private async doRemove(bookId: string, deleteFiles: boolean): Promise<void> {
    if (!this.context) return;
    try {
      if (deleteFiles) {
        await this.deleteBookFilesAndRecords(bookId);
      }
      await PreferenceService.removeFavorites(this.favoriteIdsByBookId.get(bookId) ?? [bookId]);
      // 移出书架保留书籍身份，未收藏记录仍需续读。
      await this.loadFavorites();
    } catch (_e) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '移除失败，请重试' });
      } catch (_e2) { /* ignore */ }
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 套装底色 + 同色系暗纹；默认套装仍用暖色渐变。
      ThemeBackgroundComponent()

      HdsNavigation() {
        Refresh({ refreshing: $$this.isRefreshing, builder: this.refreshIndicator() }) {
          if (!this.loading && this.filteredBooks(this.favoriteBooks).length === 0) {
            List({ scroller: this.listScroller }) {
              ListItemGroup({ header: this.buildShelfContentInset() }) {
                ListItem() {
                  Column({ space: AppSpace.Md }) {
                    if (this.favoriteBooks.length === 0) {
                      Text($r('app.string.shelf_empty_hint')).fontSize(AppFont.Body)
                        .fontColor($r('sys.color.font_secondary'))
                        .textAlign(TextAlign.Center)
                    } else {
                      Text($r('app.string.shelf_filter_empty')).fontSize(AppFont.Body)
                        .fontColor($r('sys.color.font_secondary'))
                      Text($r('app.string.shelf_filter_empty_hint')).fontSize(AppFont.Caption)
                        .fontColor($r('sys.color.font_tertiary'))
                    }
                  }.width('100%').padding(AppSpace.Lg)
                }
              }
            }.width('100%').height('100%').scrollBar(BarState.Off)
            .contentEndOffset(WindowUtils.getFloatingTabBottomVp())
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          } else if (this.viewMode === 0) {
            // 三列书卡复用 List 的首尾边界，内容不足一屏时回弹后仍停留在安全起点。
            List({ scroller: this.listScroller }) {
              ListItemGroup({ header: this.buildShelfContentInset(), space: AppSpace.Md }) {
                LazyForEach(this.bookDataSource, (book: Book) => {
                  ListItem() {
                    this.buildBookTile(book)
                  }
                  // key 带上"总章数 + 当前章索引":LazyForEach 对相同 key 的项会复用旧节点、
                  // 不重跑 buildBookTile。刷新后章数 742→758 但 book.id 不变 → 贴片卡在旧值。
                  // 把会变的展示量编进 key,值一变 key 变 → 强制重建贴片。
                }, (book: Book) => JSON.stringify([book.id, book.title, book.cover, this.showShelfSource,
                  this.getChapterCount(book), this.chapterIdxMap[book.id] ?? -1]))
              }
            }
            .lanes(this.bookColumns, AppSpace.Md)
            .cachedCount(6)
            .width('100%')
            .height('100%')
            .padding({
              left: AppSpace.PageX,
              right: AppSpace.PageX
            })
            .contentEndOffset(WindowUtils.getFloatingTabBottomVp())
            .scrollBar(BarState.Off)
            // 内容不足一屏时也提供原生回弹。
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .backgroundColor(Color.Transparent)
          } else {
            List({ scroller: this.listScroller }) {
              ListItemGroup({ header: this.buildShelfContentInset() }) {
                LazyForEach(this.bookDataSource, (book: Book) => {
                  ListItem() {
                    this.buildListItem(book)
                  }
                }, (book: Book) => JSON.stringify([book.id, book.title, book.cover, this.showShelfSource,
                  this.getChapterCount(book), this.chapterIdxMap[book.id] ?? -1]))
              }
              .divider({
                strokeWidth: 0.5,
                color: $r('sys.color.comp_divider'),
                startMargin: 88
              })
            }
            .cachedCount(6)
            .width('100%')
            .height('100%')
            .padding({
              left: AppSpace.PageX,
              right: AppSpace.PageX
            })
            .contentEndOffset(WindowUtils.getFloatingTabBottomVp())
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .backgroundColor(Color.Transparent)
          }
        }
        .onRefreshing(() => {
          this.refreshOnlineBooks().finally(() => { this.isRefreshing = false; });
        })
        .refreshOffset(64)
        .pullToRefresh(!this.removingBook && !this.checkingUpdates)
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        avoidLayoutSafeArea: true,
        content: this.shelfTitleBarContent,
        style: {
          scrollEffectOpts: {
            scrollEffectType: HdsCompat.scrollEffect
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: Color.Transparent
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary')
              },
              menuStyle: {
                iconColor: $r('sys.color.icon_primary')
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: Color.Transparent
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary')
              },
              menuStyle: {
                iconColor: $r('sys.color.icon_primary')
              }
            }
          },
          systemMaterialEffect: HdsCompat.material
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .bindToScrollable([this.listScroller])
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)

      Column().width(0).height(0)
        .bindSheet($$this.showBookEditor, this.buildBookEditor(), {
          height: '85%', detents: ['85%', '45%', SheetSize.LARGE], preferType: SheetType.BOTTOM, dragBar: true, showClose: true, backgroundColor: AppMaterial.SheetBackground,
          blurStyle: AppMaterial.SheetBlur, systemMaterial: AppMaterial.Sheet
        })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onSizeChange((_oldSize: SizeOptions, size: SizeOptions): void => {
      if (typeof size.width === 'number' && size.width > 0) {
        this.bookColumns = AdaptiveLayout.bookColumns(size.width);
      }
    })
  }

  @Builder
  buildBookEditor() {
    if (this.editingBook !== null) {
      BookEditSheet({ book: this.editingBook, groupOnly: false, onSaved: (book: Book): void => {
        SearchCache.put(book);
        AudioService.getInstance().updateBookPresentation(book);
        TextToSpeechService.getInstance().updateBookPresentation(book);
        WidgetUpdater.updateBookPresentation(book).catch((): void => {});
        this.showBookEditor = false;
        this.shelfGroups = BookPresentation.groups.slice();
        this.syncFavoriteBook(book);
      } })
    }
  }

  @Builder
  refreshIndicator() {
    Row() {
      if (this.isRefreshing) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color(AppColor.Brand)
      }
    }
    .height(56)
    .justifyContent(FlexAlign.Center)
      .translate({
        y: WindowUtils.getStatusBarHeightVp() + SHELF_FILTER_TOP_OFFSET + this.shelfHeaderHeight()
      })
  }

  @Builder
  buildShelfContentInset() {
    // 使用真实的全宽组头预留导航空间，避免沉浸导航绑定后的滚动偏移影响首行位置。
    Column()
      .width('100%')
      .height(this.topSafeVp + SHELF_FILTER_TOP_OFFSET + this.shelfHeaderHeight() + SHELF_CONTENT_GAP)
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  buildShelfTitleBar() {
    Row({ space: 8 }) {
      Text($r('app.string.shelf_title'))
        .fontSize(AppFont.HeroTitle).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      ImmersiveCircleButton({
        useMaterial: false,
        icon: $r('sys.symbol.arrow_down_circle'),
        label: $r('app.string.download_open_manager'),
        onPress: (): void => this.openDownloadManager()
      })
        .enabled(!this.removingBook)
      ImmersiveCircleButton({
        useMaterial: false,
        icon: this.viewMode === 0 ? $r('sys.symbol.list_bullet') : $r('sys.symbol.square_grid_2x2'),
        label: this.viewMode === 0 ? $r('app.string.shelf_view_list') : $r('app.string.shelf_view_grid'),
        onPress: (): void => this.toggleViewMode()
      })
        .enabled(!this.removingBook)
    }
    .width('100%').height(MINI_TITLE_BAR_HEIGHT)
    .padding({ left: AppSpace.PageX, right: AppSpace.PageX })
    .clip(false)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  buildShelfFilter() {
    Column({ space: 6 }) {
      Search({ value: this.shelfKeyword, placeholder: $r('app.string.shelf_search_hint'),
        controller: this.shelfSearchController })
        .id('shelf-search-input')
        .height(44).width('100%').enabled(!this.removingBook)
        .placeholderFont({ size: AppFont.Body, weight: FontWeight.Regular })
        .textFont({ size: AppFont.Body, weight: FontWeight.Regular })
        .borderRadius(22).clip(true)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onChange((value: string): void => {
          this.shelfKeyword = value;
          this.bookDataSource.setBooks(this.filteredBooks(this.favoriteBooks));
          this.listScroller.scrollToIndex(0);
        })
      Stack({ alignContent: Alignment.Bottom }) {
        CapsuleSegmentButtonV2({
          items: this.shelfFilterItems,
          selectedIndex: this.shelfFilter,
          $selectedIndex: (index: number): void => this.selectShelfFilter(index),
          itemFontSize: LengthMetrics.fp(13),
          itemSelectedFontSize: LengthMetrics.fp(13),
          itemFontColor: ColorMetrics.resourceColor($r('sys.color.font_secondary')),
          itemSelectedFontColor: ColorMetrics.resourceColor(HomeTheme.Accent),
          itemSelectedBackgroundColor: ColorMetrics.resourceColor(Color.Transparent),
          itemMinHeight: LengthMetrics.vp(34),
          buttonMinHeight: LengthMetrics.vp(38),
          buttonPadding: LengthMetrics.vp(2),
          backgroundSystemMaterial: AppMaterial.FloatingControl
        })
        .width('100%')

        Row() {
          ForEach([0, 1, 2, 3], (index: number) => {
            Column() {
              Row()
                .width(18)
                .height(2)
                .borderRadius(1)
                .backgroundColor(HomeTheme.Accent)
                .opacity(this.shelfFilter === index ? 1 : 0)
            }
            .layoutWeight(1)
          }, (index: number) => index.toString())
        }
        .width('100%')
        .padding({ left: 2, right: 2, bottom: 4 })
        .hitTestBehavior(HitTestMode.None)
      }
      .width('100%').height(40)
    }
    .width('100%')
    .height(this.shelfHeaderHeight())
    .id('shelf-search-region')
    .clip(false)
    .padding({ left: AppSpace.PageX, right: AppSpace.PageX, top: 4, bottom: 4 })
    .alignItems(HorizontalAlign.Center)
  }

    // 透明明暗层沿用原封面的颜色，书脊随封面宽度缩放，不增加图片解码。
  @Builder
  buildBookSpine() {
    if (AppTheme.hasSkin) {
      CoverDecoration({ radius: 4 })
    } else {
      Row()
        .width('14%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            ['#66000000', 0],
            ['#16000000', 0.18],
            ['#38FFFFFF', 0.36],
            ['#10FFFFFF', 0.5],
            ['#30000000', 0.6],
            ['#08000000', 0.78],
            ['#00000000', 1]
          ]
        })
        .hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
    }
  }

  @Builder
  buildBookTile(book: Book) {
    Stack() {
    Column({ space: AppSpace.Xs }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.isMissingCachedBook(book)) {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('#FFE8D6D6')
            SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
              .fontSize(34)
              .fontColor(['#B3261E'])
            Text('缓存缺失')
              .fontSize(AppFont.Caption)
              .fontColor('#B3261E')
              .fontWeight(FontWeight.Medium)
              .margin({ top: 48 })
          }
          .width('100%')
          .aspectRatio(BOOKSHELF_COVER_RATIO)
          .borderRadius(0)
          .clip(true)
        } else if (book.cover && book.cover.startsWith('http')) {
          CoverImage({ url: book.cover, imgWidth: '100%', aspectRatioValue: BOOKSHELF_COVER_RATIO,
            radius: 0, themedDecoration: false, decodeW: 300, decodeH: 400 })
            .hitTestBehavior(HitTestMode.Transparent)
        } else if (book.cover && (book.cover.startsWith('/data/') || book.cover.startsWith('file://'))) {
          Image('file://' + book.cover.replace(/^file:\/\//, ''))
            .width('100%')
            .aspectRatio(BOOKSHELF_COVER_RATIO)
            .borderRadius(0)
            .objectFit(ImageFit.Cover)
            .sourceSize({ width: 300, height: 400 })
            .draggable(false)
            .hitTestBehavior(HitTestMode.Transparent)
        } else if (book.cover) {
          Image($rawfile(book.cover))
            .width('100%')
            .aspectRatio(BOOKSHELF_COVER_RATIO)
            .borderRadius(0)
            .objectFit(ImageFit.Cover)
            .draggable(false)
            .hitTestBehavior(HitTestMode.Transparent)
        } else {
          CoverImage({ title: book.title, author: book.author, localPlaceholder: book.id.startsWith('import_'),
            imgWidth: '100%', aspectRatioValue: BOOKSHELF_COVER_RATIO, radius: 0, themedDecoration: false })
        }
        this.buildBookSpine()
        this.buildTypeBadge(false, book.contentType ?? 'audio')
        this.buildSourceBadge(book)
        this.buildPinnedBadge(book)
      }
      .width('100%')
      .aspectRatio(BOOKSHELF_COVER_RATIO)
      .borderRadius({ topLeft: 3, bottomLeft: 3, topRight: 5, bottomRight: 5 })
      .clip(true)
      .shadow({ radius: 6, color: '#26000000', offsetX: 2, offsetY: 3 })
      // 展示子树不参与触摸命中，封面/占位图的原生长按不能抢走书卡菜单。
      .hitTestBehavior(HitTestMode.None)

      Text(book.title)
        .fontSize(AppFont.Body)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .copyOption(CopyOptions.None)
      Text(this.getProgressText(book))
        .fontSize(AppFont.Caption)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .width('100%')
        .copyOption(CopyOptions.None)
    }
    .draggable(false)
    .bindContextMenu(this.bookActions(book), ResponseType.LongPress, this.bookMenuOptions())
    .onClick((): void => {
      if (!this.showBookActions && !this.resolvingTocId) this.handleBookTap(book);
    })
    }
    .width('100%')
    // 右键绑定在独立容器，避免同一节点重复设置上下文菜单覆盖长按入口。
    .bindContextMenu(this.bookActions(book), ResponseType.RightClick, this.bookMenuOptions())
  }

  @Builder
  buildSourceBadge(book: Book) {
    if (this.showShelfSource && book.sourceUrl) {
      Column() {
        Blank()
        Text(this.sourceNames.get(book.sourceUrl) || book.sourceUrl)
          .fontSize(10)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .width('100%')
          .backgroundColor('#99000000')
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  buildPinnedBadge(book: Book) {
    if (this.pinnedBookIds.has(book.id)) {
      Row() {
        Blank()
        SymbolGlyph($r('sys.symbol.pin'))
          .fontSize(16)
          .fontColor([AppColor.OnBrand])
          .padding(5)
          .backgroundColor(AppColor.Brand)
          .borderRadius(AppRadius.Pill)
          .accessibilityText($r('app.string.shelf_pin'))
      }
      .width('100%')
      .padding(4)
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  buildTypeBadge(small: boolean, contentType: string) {
    Row() {
      Text(contentType === 'audio' ? $r('app.string.shelf_badge_audio') : $r('app.string.shelf_badge_text'))
        .fontSize(small ? 9 : 10)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
    }
    .padding({
      left: small ? 5 : 6,
      right: small ? 5 : 6,
      top: small ? 2 : 3,
      bottom: small ? 2 : 3
    })
    .backgroundColor(contentType === 'audio' ? '#CCFF8800' : '#CC4E7FA8')
    .borderRadius(AppRadius.Sm)
    .margin({ top: small ? 5 : 6, left: small ? 10 : 14 })
  }

  @Builder
  buildListItem(book: Book) {
    Stack() {
    Row({ space: AppSpace.Md }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (book.cover && book.cover.startsWith('http')) {
          CoverImage({ url: book.cover, imgWidth: 72, imgHeight: 100, useFixedHeight: true,
            radius: 0, themedDecoration: false, decodeW: 300, decodeH: 400 })
            .hitTestBehavior(HitTestMode.Transparent)
        } else if (book.cover && (book.cover.startsWith('/data/') || book.cover.startsWith('file://'))) {
          Image('file://' + book.cover.replace(/^file:\/\//, ''))
            .width(72)
            .height(100)
            .borderRadius(0)
            .objectFit(ImageFit.Cover)
            .sourceSize({ width: 300, height: 400 })
            .draggable(false)
            .hitTestBehavior(HitTestMode.Transparent)
        } else if (book.cover) {
          Image($rawfile(book.cover)).width(72).height(100).borderRadius(0)
            .objectFit(ImageFit.Cover).draggable(false).hitTestBehavior(HitTestMode.Transparent)
        } else {
          CoverImage({ title: book.title, author: book.author, localPlaceholder: book.id.startsWith('import_'),
            imgWidth: 72, imgHeight: 100, useFixedHeight: true, radius: 0, themedDecoration: false })
        }
        this.buildBookSpine()
        this.buildTypeBadge(true, book.contentType ?? 'audio')
        this.buildSourceBadge(book)
      }
      .width(72)
      .height(100)
      .borderRadius({ topLeft: 3, bottomLeft: 3, topRight: 5, bottomRight: 5 })
      .clip(true)
      .shadow({ radius: 5, color: '#26000000', offsetX: 2, offsetY: 2 })
      .hitTestBehavior(HitTestMode.None)

      Column({ space: 6 }) {
        Text(book.title)
          .fontSize(AppFont.BodyL)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(book.author)
          .fontSize(AppFont.Caption)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.getProgressText(book))
          .fontSize(AppFont.Caption)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      if (this.pinnedBookIds.has(book.id)) {
        SymbolGlyph($r('sys.symbol.pin')).fontSize(18).fontColor([AppColor.Brand])
          .accessibilityText($r('app.string.shelf_pin'))
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .padding({ top: AppSpace.RowY, bottom: AppSpace.RowY })
    .borderRadius(AppRadius.Sm)
    .draggable(false)
    .bindContextMenu(this.bookActions(book), ResponseType.LongPress, this.bookMenuOptions())
    .onClick((): void => {
      if (!this.showBookActions && !this.resolvingTocId) this.handleBookTap(book);
    })
    }
    .width('100%')
    .bindContextMenu(this.bookActions(book), ResponseType.RightClick, this.bookMenuOptions())
  }

}
