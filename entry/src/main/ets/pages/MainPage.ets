import { GeneralSettings } from '../model/GeneralSettings';
import { Book } from '../model/Book';
import { TextToSpeechService } from '../service/text/TextToSpeechService';
import { TextToSpeechState } from '../model/TextToSpeechState';
import { HdsCompat, CompatibleTabsModifier } from '../utils/HdsCompat';
import { PlatformCompat } from '../utils/PlatformCompat';
import { common } from '@kit.AbilityKit';
import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, HdsTabsFloatingStyle } from '@kit.UIDesignKit';
import { emitter } from '@kit.BasicServicesKit';
import { PlayerState, PLAYER_STATE_KEY } from '../model/PlayerState';
import { HomePage } from './HomePage';
import { HomeBlockSection } from '../model/BookSource';
import { FavoritePage } from './FavoritePage';
import { ReadingStatsPage } from './ReadingStatsPage';
import { ProfilePage } from './ProfilePage';
import { MiniPlayer } from '../components/MiniPlayer';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { PlayerDragTransition } from '../utils/PlayerDragTransition';
import { AudioService } from '../service/AudioService';
import { DataService } from '../service/DataService';
import { PreferenceService } from '../service/PreferenceService';
import { PlaybackStore } from '../service/PlaybackStore';
import { WindowUtils } from '../utils/WindowUtils';
import { EVT_SWITCH_TAB } from './ImportPage';
import { WebViewAudioExtractorHost } from '../service/builtin/WebViewAudioExtractor';
import { WebEngineGate } from '../service/WebEngineGate';
import { AppColor, HomeTheme, AppTheme } from '../theme/Theme';
import { ThemeIcons, ThemeIconRole } from '../theme/ThemeIcons';
import { BookSourceAudioWebRuntimeHost } from '../service/rulesource/light/BookSourceAudioWebRuntimeHost';
import { RuleSourceImportWebHost } from '../service/rulesource/light/RuleSourceImportWebHost';

/**
 * 全局事件:点击某本书时调,统一收口路由策略。
 */
export const EVT_NAVIGATE_TO_BOOK = 'app.navigate.to.book';

export interface NavigateToBookPayload {
  bookId: string;
  chapterId?: string;
  progressMs?: number;
  forceDetail?: boolean;
}

const FLOATING_BOTTOM: number = 4;
const FLOATING_MIN_SAFE_BOTTOM: number = 8;

@ComponentV2
export struct MainPage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Event onBackHandlerChange: (handler: (() => boolean) | undefined) => void = () => {};
  @Event onHomeShownHandlerChange: (handler: (() => void) | undefined) => void = () => {};
  private pendingHomeResume: (() => void) | undefined = undefined;
  private homeBackHandler: (() => boolean) | undefined = undefined;
  private shelfBackHandler: (() => boolean) | undefined = undefined;
  private recordsBackHandler: (() => boolean) | undefined = undefined;
  @Local currentTab: number = 0;
  @Local tabContentOpacity: number = 1;
  // 原生 Tabs 已完成选中切换；这里只镜像物理索引，供后续属性刷新使用。
  // 不参与状态观测，避免 onChange 再刷新 HdsTabs 整组属性并重建 MiniPlayer。
  private nativeTabIndex: number = 0;
  @Local tabsReady: boolean = false;
  private defaultTabRequest: number = 0;
  private pendingInitialTab: number = -1;
  @Local playerState: PlayerState = AppStorageV2.connect(PlayerState, PLAYER_STATE_KEY, () => new PlayerState())!;
  @Local speechState: TextToSpeechState = TextToSpeechService.getInstance().state;
  @Local viewportWidth: number = 0;
  @Local viewportHeight: number = 0;
  @Local bottomSafeVp: number = WindowUtils.getBottomSafeVp();

  /** 隐藏 Web 宿主的按需挂载门控:引擎首次被调用时置位,据此条件渲染对应 Host */
  private gate: WebEngineGate = WebEngineGate.instance;
  private tabController: HdsTabsController = new HdsTabsController();
  private context: common.UIAbilityContext | null = null;
  private switchTabHandler: (e: emitter.EventData) => void = (e) => this.onSwitchTabEvent(e);
  /** 各逻辑 Tab 页的滚动控制器,用于双击 Tab 回顶部；不含中间播放入口。 */
  private scrollers: Map<number, Scroller> = new Map();
  /** 上一次 Tab 点击时间,用于双击检测 */
  @Local generalSettings: GeneralSettings = GeneralSettings.current;
  private lastTabClickTime: number = 0;
  private lastTabClickIndex: number = -1;
  private viewportUpdateTimerId: number = -1;
  private safeAreaChangeHandler: (topVp: number, bottomVp: number) => void =
    (_topVp: number, bottomVp: number): void => {
      if (Math.abs(this.bottomSafeVp - bottomVp) < 0.1) return;
      this.bottomSafeVp = bottomVp;
    };

  aboutToAppear(): void {
    this.onHomeShownHandlerChange((): void => {
      const resume = this.pendingHomeResume;
      this.pendingHomeResume = undefined;
      resume?.();
    });
    this.onBackHandlerChange((): boolean => {
      if (this.currentTab === 1) return this.shelfBackHandler?.() ?? false;
      if (this.currentTab === 2 && this.generalSettings.historyEnabled) return this.recordsBackHandler?.() ?? false;
      return this.currentTab === 0 && (this.homeBackHandler?.() ?? false);
    });
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    AudioService.getInstance().bind(this.playerState, this.context);
    this.restoreLastPlayed();
    WindowUtils.setStatusBarLight(false);
    WindowUtils.addSafeAreaListener(this.safeAreaChangeHandler);
    WindowUtils.refreshAvoidArea();
    this.restoreDefaultTab();
    emitter.on(EVT_SWITCH_TAB, this.switchTabHandler);
    emitter.on(EVT_NAVIGATE_TO_BOOK, this.navigateBookHandler);
  }

  aboutToDisappear(): void {
    this.defaultTabRequest++;
    this.onHomeShownHandlerChange(undefined);
    this.pendingHomeResume = undefined;
    this.onBackHandlerChange(undefined);
    this.cancelLayoutTimers();
    WindowUtils.removeSafeAreaListener(this.safeAreaChangeHandler);
    emitter.off(EVT_SWITCH_TAB, this.switchTabHandler);
    emitter.off(EVT_NAVIGATE_TO_BOOK, this.navigateBookHandler);
  }

  private cancelLayoutTimers(): void {
    if (this.viewportUpdateTimerId !== -1) {
      clearTimeout(this.viewportUpdateTimerId);
      this.viewportUpdateTimerId = -1;
    }
  }

  private handleViewportSizeChange(newValue: SizeOptions): void {
    if (typeof newValue.width !== 'number' || typeof newValue.height !== 'number') return;
    const width: number = newValue.width;
    const height: number = newValue.height;
    if (Math.abs(width - this.viewportWidth) < 1 && Math.abs(height - this.viewportHeight) < 1) return;
    if (this.viewportUpdateTimerId !== -1) clearTimeout(this.viewportUpdateTimerId);
    this.viewportUpdateTimerId = setTimeout(() => {
      this.viewportUpdateTimerId = -1;
      this.viewportWidth = width;
      this.viewportHeight = height;
      WindowUtils.refreshAvoidArea();
    }, 0);
  }

  /** 有当前播放/朗读会话时才占用底栏中间入口。 */
  private hasPlayerTab(): boolean {
    return this.currentPlaybackBook() !== null;
  }

  /** 中间播放入口物理索引；无会话时返回 -1。 */
  private playerTabIndex(): number {
    return this.hasPlayerTab() ? 2 : -1;
  }

  /** 逻辑页签（0 首页 / 1 书架 / 2 记录 / 3 我的）→ 物理 HdsTabs 索引。 */
  private logicalToPhysical(logical: number): number {
    if (logical < 2) return logical;
    const playerOffset: number = this.hasPlayerTab() ? 1 : 0;
    if (this.generalSettings.historyEnabled) return logical + playerOffset;
    return 2 + playerOffset;
  }

  /** 物理索引 → 逻辑页签；播放入口返回 -1。 */
  private physicalToLogical(physical: number): number {
    if (this.hasPlayerTab() && physical === 2) return -1;
    if (physical < 2) return physical;
    if (this.hasPlayerTab()) {
      if (this.generalSettings.historyEnabled) return physical - 1;
      return 3;
    }
    if (this.generalSettings.historyEnabled) return physical;
    return 3;
  }

  private navigateBookHandler: (e: emitter.EventData) => void = (e) => this.onNavigateBookEvent(e);

  private onNavigateBookEvent(e: emitter.EventData): void {
    const data = e.data as Record<string, Object> | undefined;
    if (!data) return;
    const bookId = data['bookId'] as string;
    if (!bookId) return;
    const chapterId = (data['chapterId'] as string) ?? '';
    const progressMs = (data['progressMs'] as number) ?? 0;
    const forceDetail = (data['forceDetail'] as boolean) === true;
    this.navigateToBook(bookId, chapterId, progressMs, forceDetail);
  }

  private navigateToBook(bookId: string, chapterId: string, progressMs: number, forceDetail: boolean): void {
    if (forceDetail) {
      this.navStack.pushPathByName('detail', bookId);
      return;
    }
    if (PlaybackStore.getInstance().isCurrentBook(bookId)) {
      this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
        this.navStack.pushPathByName('player', bookId, false);
      });
      return;
    }
    if (chapterId) {
      const params: Record<string, Object> = {
        'bookId': bookId,
        'chapterId': chapterId,
        'progressMs': progressMs
      };
      this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
        this.navStack.pushPathByName('player', params, false);
      });
      return;
    }
    this.navStack.pushPathByName('detail', bookId);
  }

  private onSwitchTabEvent(e: emitter.EventData): void {
    const data = e.data as Record<string, Object> | undefined;
    if (!data) return;
    const v = data['index'];
    if (typeof v !== 'number') return;
    const idx = v as number;
    if (idx < 0 || idx > 3) return;
    if (!this.tabsReady) {
      this.changeTab(idx);
      return;
    }
    setTimeout(() => {
      this.changeTab(idx);
    }, 60);
  }

  private async restoreDefaultTab(): Promise<void> {
    if (this.tabsReady) return;
    const request = ++this.defaultTabRequest;
    let index: number = 0;
    try {
      index = await PreferenceService.getDefaultTab();
    } catch (_error) {
      // 偏好读取失败时仍可进入首页。
    }
    if (request !== this.defaultTabRequest) return;
    if (this.pendingInitialTab !== -1) index = this.pendingInitialTab;
    if (!this.generalSettings.historyEnabled && index === 2) index = 0;
    this.currentTab = index;
    this.nativeTabIndex = this.logicalToPhysical(index);
    this.pendingInitialTab = -1;
    this.tabsReady = true;
  }

  /**
   * 首屏挂载前保存目标页，挂载后的跳转使用 HdsTabs 原生切换。
   */
  private changeTab(index: number): void {
    if (!Number.isInteger(index) || index < 0 || index > 3) return;
    if (!this.tabsReady) {
      this.pendingInitialTab = index;
      return;
    }
    if (!this.generalSettings.historyEnabled && index === 2) index = 0;
    if (index === this.currentTab) return;
    this.tabController.changeIndex(this.logicalToPhysical(index));
  }

  @Monitor('generalSettings.historyEnabled')
  private onHistoryVisibilityChanged(): void {
    if (!this.tabsReady) return;
    const logical = !this.generalSettings.historyEnabled && this.currentTab === 2 ? 0 : this.currentTab;
    this.currentTab = logical;
    this.nativeTabIndex = this.logicalToPhysical(logical);
    this.tabController.changeIndex(this.nativeTabIndex);
    this.lastTabClickIndex = -1;
  }

  /** 播放会话出现/消失时重算物理索引，避免记录/我的错位。 */
  @Monitor('playerState.currentBook', 'speechState.active', 'speechState.bookId')
  private onPlayerTabVisibilityChanged(): void {
    if (!this.tabsReady) return;
    this.nativeTabIndex = this.logicalToPhysical(this.currentTab);
    this.tabController.changeIndex(this.nativeTabIndex);
    this.lastTabClickIndex = -1;
  }

  private async restoreLastPlayed(): Promise<void> {
    if (this.playerState.currentBook) return;
    const last = await PreferenceService.getLastPlayed();
    if (!last) return;
    const book = await DataService.getBookById(this.context!, last.bookId);
    if (!book) return;
    const idx = DataService.resolveChapterIndex(book, last.chapterId, last.chapterTitle);
    if (idx < 0) return;
    const chapter = book.chapters[idx];
    // 独立 KV 为权威:贴回跳过头尾,纠正缓存书壳可能丢失的 skip
    await PreferenceService.applySkipConfig(book);
    this.playerState.currentBook = book;
    this.playerState.currentChapter = chapter;
    this.playerState.progressMs = last.progressMs;
    const savedDuration = (last.durationMs && last.durationMs > 0)
      ? last.durationMs
      : (chapter.duration > 0 ? chapter.duration * 1000 : 0);
    this.playerState.durationMs = savedDuration;
    this.playerState.isPlaying = false;
    PlaybackStore.getInstance().update(
      book.id, chapter.id, idx,
      chapter.source?.value ?? '', false
    );
  }

  private buildTabBar(icon: Resource, label: string, role: ThemeIconRole): BottomTabBarStyle {
    if (AppTheme.hasSkin) {
      return new BottomTabBarStyle(ThemeIcons.paper(role), label)
        .iconStyle({ unselectedColor: AppTheme.TextSecondary, selectedColor: AppColor.Brand })
        .labelStyle({ unselectedColor: AppTheme.TextSecondary, selectedColor: AppColor.Brand });
    }
    return new BottomTabBarStyle(
      {
        normal: new SymbolGlyphModifier(icon).fontColor([$r('sys.color.font_primary')]).fontSize(24),
        selected: new SymbolGlyphModifier(icon).fontColor([AppColor.Brand]).fontSize(26)
      },
      label
    ).labelStyle({
      unselectedColor: $r('sys.color.font_primary'),
      selectedColor: AppColor.Brand
    });
  }

  /** 底栏正中的迷你播放器；仅在有播放会话时挂载。 */
  @Builder
  centerPlayTabBar(): void {
    Column() {
      MiniPlayer({
        book: this.currentPlaybackBook(),
        chapterTitle: this.speechState.active ? this.speechState.error || this.speechState.chapterTitle
          : this.playerState.currentChapter?.title ?? '',
        playing: this.speechState.active ? this.speechState.playing : this.playerState.isPlaying,
        loading: this.speechState.active ? this.speechState.loading : this.playerState.isLoading,
        progressPercent: this.playbackProgressPercent(),
        collapsed: true,
        onPlayerPanStart: (offsetY: number): void => this.beginPlayerDrag(offsetY),
        onPlayerPanUpdate: (offsetY: number): void => PlayerDragTransition.getInstance().update(offsetY),
        onPlayerPanEnd: (offsetY: number, velocityY: number): void =>
          PlayerDragTransition.getInstance().end(offsetY, velocityY),
        onPlayerPanCancel: (): void => { PlayerDragTransition.getInstance().cancel(); },
        onTapBody: (): void => this.navigateToPlayer(),
        onToggle: (): void => this.togglePlayback(),
        onNext: (): void => this.playNext(),
        onExpand: (): void => this.navigateToPlayer()
      })
    }
    .width(52)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityText($r('app.string.mini_player_open'))
  }

  private floatingBarStyle(): HdsTabsFloatingStyle | undefined {
    if (!PlatformCompat.floatingTabs) return undefined;
    // 有播放入口时略宽；无会话时四入口即可。
    const withPlayer: boolean = this.hasPlayerTab();
    return {
      barWidth: withPlayer
        ? { smallWidth: 360, mediumWidth: 400, largeWidth: 440 }
        : { smallWidth: 300, mediumWidth: 340, largeWidth: 380 },
      barSideMargin: Math.max(16, (this.viewportWidth - 720) / 2),
      barBottomMargin: Math.max(this.bottomSafeVp, FLOATING_MIN_SAFE_BOTTOM) + FLOATING_BOTTOM,
      gradientMask: { maskColor: HomeTheme.FloatingBarMask, maskHeight: 92 },
      systemMaterialEffect: HdsCompat.adaptiveMaterial,
      lightColor: AppColor.Brand,
      adaptToHandedness: this.generalSettings.adaptiveHandedness
    };
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 主容器统一套装底色与暗纹；子页透明叠放，避免纯色盖住底图。
      ThemeBackgroundComponent()
      if (this.tabsReady) {
      // 属性刷新仍读取最新选中页；子页 visible 单独响应 currentTab，不反向重配底栏。
      HdsTabs({ controller: this.tabController, index: this.nativeTabIndex }) {
        TabContent() {
          HomePage({
            visible: this.currentTab === 0,
            onSourceSettings: (sourceUrl: string): void => {
              this.navStack.pushPathByName('ruleSourceExplore', sourceUrl);
            },
            onManageSources: (resume: () => void): void => {
              this.pendingHomeResume = resume;
              this.navStack.pushPath({ name: 'ruleSources' });
            },
            onBackHandlerChange: (handler: (() => boolean) | undefined): void => {
              this.homeBackHandler = handler;
            },
            onBookTap: (id: string) => this.navigateToBook(id, '', 0, false),
            onSearchTap: () => this.navStack.pushPathByName('search', null),
            onBlockMore: (block: HomeBlockSection) => this.openBlockMore(block),
            onCategoryTap: (sourceUrl: string, sourceName: string, title: string, url: string) =>
              this.openCategory(sourceUrl, sourceName, title, url),
            onScrollerReady: (scroller: Scroller) => { this.scrollers.set(0, scroller); }
          })
          .opacity(this.tabContentOpacity)
        }
        .tabBar(this.buildTabBar($r('sys.symbol.house_fill'), '首页', ThemeIconRole.Home))

        TabContent() {
          FavoritePage({
            onBackHandlerChange: (handler: (() => boolean) | undefined): void => {
              this.shelfBackHandler = handler;
            },
            visible: this.currentTab === 1,
            navStack: this.navStack,
            onBookTap: (id: string) => this.navigateToBook(id, '', 0, false),
            onScrollerReady: (scroller: Scroller) => { this.scrollers.set(1, scroller); }
          })
          .opacity(this.tabContentOpacity)
        }
        .tabBar(this.buildTabBar($r('sys.symbol.bookshelf'), '书架', ThemeIconRole.Shelf))

        // 中间播放入口：仅有播放/朗读会话时显示，点按打开播放器并回到原 Tab。
        if (this.hasPlayerTab()) {
        TabContent() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Transparent)
        }
        .tabBar(this.centerPlayTabBar())
        }

        if (this.generalSettings.historyEnabled) {
        TabContent() {
          ReadingStatsPage({
            onBackHandlerChange: (handler: (() => boolean) | undefined): void => {
              this.recordsBackHandler = handler;
            },
            navStack: this.navStack,
            inTab: true,
            onScrollerReady: (scroller: Scroller) => { this.scrollers.set(2, scroller); }
          })
          .opacity(this.tabContentOpacity)
        }
        .tabBar(this.buildTabBar($r('sys.symbol.calendar_fill'), '记录', ThemeIconRole.Record))
        }

        TabContent() {
          ProfilePage({
            navStack: this.navStack,
            onScrollerReady: (scroller: Scroller) => { this.scrollers.set(3, scroller); }
          })
          .opacity(this.tabContentOpacity)
        }
        .tabBar(this.buildTabBar($r('sys.symbol.person_fill'), '我的', ThemeIconRole.Profile))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .attributeModifier(new CompatibleTabsModifier(this.floatingBarStyle(), 56 + this.bottomSafeVp))
      .onTabBarClick((index: number) => {
        if (index === this.playerTabIndex()) {
          this.navigateToPlayer();
          this.tabController.changeIndex(this.logicalToPhysical(this.currentTab));
          return;
        }
        const logical = this.physicalToLogical(index);
        const now = Date.now();
        const DOUBLE_TAP_DELAY = 300;
        if (logical >= 0 && logical === this.lastTabClickIndex &&
          (now - this.lastTabClickTime) < DOUBLE_TAP_DELAY) {
          const scroller = this.scrollers.get(logical);
          if (scroller) {
            try { scroller.scrollEdge(Edge.Top); } catch (_e) { /* ignore */ }
          }
        }
        this.lastTabClickTime = now;
        this.lastTabClickIndex = logical;
      })
      .onChange((index: number) => {
        if (index === this.playerTabIndex()) {
          this.tabController.changeIndex(this.logicalToPhysical(this.currentTab));
          return;
        }
        const logical = this.physicalToLogical(index);
        if (logical < 0) return;
        const changed = this.currentTab !== logical;
        this.nativeTabIndex = index;
        this.currentTab = logical;
        if (changed) {
          this.getUIContext().animateTo({ duration: 0 }, () => {
            this.tabContentOpacity = 0.55;
          });
          this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
            this.tabContentOpacity = 1;
          });
        }
      })
      // 仅内容淡入，底栏与中间播放入口保持稳定。
      .animationDuration(0)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }

      // 欢部分音频地址需要 ArkWeb 兜底提取，按需创建隐藏宿主。
      if (this.gate.needAudioExtractor) {
        WebViewAudioExtractorHost()
      }

      if (this.gate.needRuleBrowser) {
        BookSourceAudioWebRuntimeHost()
        RuleSourceImportWebHost()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .onSizeChange((_oldValue: SizeOptions, newValue: SizeOptions) => {
      this.handleViewportSizeChange(newValue);
    })
  }

  private openBlockMore(block: HomeBlockSection): void {
    if (!block || !block.moreUrl) return;
    const params: Record<string, Object> = {
      'sourceUrl': block.sourceUrl,
      'sourceName': block.sourceName,
      'title': block.title,
      'moreUrl': block.moreUrl
    };
    this.navStack.pushPathByName('blockMore', params);
  }

  /** 分类入口:复用 blockMore 路由展示分类书单 */
  private openCategory(sourceUrl: string, sourceName: string, title: string, url: string): void {
    if (!sourceUrl || !url) return;
    const params: Record<string, Object> = {
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'title': title,
      'moreUrl': url
    };
    this.navStack.pushPathByName('blockMore', params);
  }

  private beginPlayerDrag(offsetY: number): void {
    const book = this.currentPlaybackBook();
    const paths = this.navStack.getAllPathName();
    if (book === null || paths[paths.length - 1] !== 'home') return;
    const transition = PlayerDragTransition.getInstance();
    if (transition.state.active) return;
    const origin = transition.capture(this.getUIContext());
    if (origin === undefined || !transition.begin(this.viewportHeight, offsetY, origin)) return;
    // 必须保留 Navigation 动画，才能建立可取消的原生交互式路由。
    this.navStack.pushPathByName('player', book.id);
  }

  private navigateToPlayer(): void {
    const book = this.currentPlaybackBook();
    if (book === null || PlayerDragTransition.getInstance().state.active) return;
    const bookId = book.id;
    this.getUIContext().animateTo({ duration: 500, curve: Curve.FastOutSlowIn }, () => {
      this.navStack.pushPathByName('player', bookId, false);
    });
  }

  private playNext(): void {
    if (this.speechState.active) {
      TextToSpeechService.getInstance().moveChapter(1);
      return;
    }
    if (!this.playerState.currentBook || !this.playerState.currentChapter) return;
    AudioService.getInstance().playNext();
  }

  private currentPlaybackBook(): Book | null {
    if (this.speechState.active) {
      const book = TextToSpeechService.getInstance().currentBook();
      return book?.id === this.speechState.bookId ? book : null;
    }
    return this.playerState.currentBook;
  }

  private playbackProgressPercent(): number {
    const total = this.speechState.active ? this.speechState.contentLength :
      (this.playerState.durationMs > 0 ? this.playerState.durationMs : this.playerState.savedDurationMs);
    const position = this.speechState.active ? this.speechState.charOffset : this.playerState.progressMs;
    return total > 0 ? Math.max(0, Math.min(100, position * 100 / total)) : 0;
  }

  private togglePlayback(): void {
    if (this.speechState.active) {
      const speech = TextToSpeechService.getInstance();
      if (this.speechState.playing || this.speechState.loading) speech.pause();
      else speech.resume();
    } else {
      AudioService.getInstance().toggle();
    }
  }
}
