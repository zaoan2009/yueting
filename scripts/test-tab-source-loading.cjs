// DEVECO_HOME=<Release IDE> node scripts/test-tab-source-loading.cjs
// Runs real page loading methods, source services, repository decoding and rule parsing.
// Only storage/UI/network are substituted; no device or user data is changed.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { performance } = require('node:perf_hooks');
const ide = process.env.DEVECO_HOME;
if (!ide) throw new Error('Set DEVECO_HOME to the installed Release DevEco Studio');
const ts = require(path.join(ide, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = name => fs.readFileSync(path.join(root, name + (fs.existsSync(path.join(root, name + '.ets')) ? '.ets' : '.ts')), 'utf8');
function compile(text, globals = {}) {
  const module = { exports: {} };
  const code = ts.transpileModule(text.replace(/import lazy /g, 'import ')
    .replace(/@ObservedV2\s*/g, '').replace(/@Trace\s*/g, ''), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText;
  vm.runInNewContext(code, { module, exports: module.exports, Map, Set, Date, JSON, console, ...globals });
  return module.exports;
}
const sourceUrl = index => `https://source-${index}.invalid/`;
const legacyRankingUrl = 'home://rankings';
let preferredUrl = sourceUrl(1999);
let homeContentKind = 0;
let homeUrlAudio = '';
let homeUrlText = '';
let books = [1999, 1111, 1111, 1888, -1].map((index, i) => ({
  id: index < 0 ? 'import_local' : `book-${i}`, title: `Book ${i}`,
  sourceUrl: index < 0 ? '' : sourceUrl(index), chapters: [], chapterCount: 0
}));
const preferences = {
  getHomeContentKind: async () => homeContentKind,
  setHomeContentKind: async (kind) => { homeContentKind = kind === 2 ? 2 : 1; },
  getHomeSourceUrlForKind: async (kind) => {
    if (kind === 1) return homeUrlAudio || preferredUrl;
    if (kind === 2) return homeUrlText || preferredUrl;
    return preferredUrl;
  },
  setHomeSourceUrlForKind: async (kind, url) => {
    const resolved = kind === 2 ? 2 : 1;
    if (resolved === 2) homeUrlText = url; else homeUrlAudio = url;
    preferredUrl = url;
    homeContentKind = resolved;
  },
  getHomeSourceUrl: async () => {
    if (homeContentKind === 1 || homeContentKind === 2) {
      return preferences.getHomeSourceUrlForKind(homeContentKind);
    }
    return preferredUrl;
  },
  setHomeSourceUrl: async (url) => {
    await preferences.setHomeSourceUrlForKind(homeContentKind === 2 ? 2 : 1, url);
  },
  getShelfFavorites: async () => books.map(book => book.id),
  getPinnedFavorites: async () => [], getHistory: async () => [], getLastPlayed: async () => null
};
const stubs = {
  '@kit.AbilityKit': {}, '@kit.ArkData': {}, '@kit.ArkTS': {},
  'service/rulesource/LocalRuleSourceCodec': {},
  'service/PreferenceService': { PreferenceService: preferences },
  'service/BookSourceService': {}, 'service/rulesource/LocalRulePanelService': {}
};
const modules = new Map();
function load(name) {
  if (stubs[name]) return stubs[name];
  if (!modules.has(name)) {
    modules.set(name, compile(read(name), { require: id => load(id.startsWith('.')
      ? path.posix.normalize(path.posix.join(path.posix.dirname(name), id)) : id) }));
  }
  return modules.get(name);
}
const { SourceDataService: sources } = load('service/SourceDataService');
const { HomeSourceService: homeService } = load('service/rulesource/HomeSourceService');
const { LocalRuleSourceRepository: repository } = load('service/rulesource/LocalRuleSourceRepository');
const { LocalRuleSourceImportParser: parser } = load('service/rulesource/LocalRuleSourceImportParser');
const rows = new Map(Array.from({ length: 2000 }, (_, i) => {
  const definition = {
    bookSourceUrl: sourceUrl(i), bookSourceName: `Source ${i}`, bookSourceGroup: 'fixture',
    bookSourceType: i % 2, enabled: i !== 1888, enabledExplore: true,
    exploreUrl: '分类::/list', searchUrl: '/search?q={{key}}',
    ruleSearch: { bookList: 'article', bookUrl: 'a@href', name: 'a@text' },
    ruleExplore: { bookList: 'article', bookUrl: 'a@href', name: 'a@text' },
    ruleContent: { content: 'p@text', audioUrl: 'audio@src' },
    jsLib: '/*' + 'fixture helper '.repeat(256) + '*/'
  };
  return [sourceUrl(i), [sourceUrl(i), definition.bookSourceName, i % 2, 'fixture',
    JSON.stringify(definition), i !== 1888 ? 1 : 0, 0, '', 1, 0, 0, i, 0]];
}));
let fullReads = 0, pointReads = 0, parsedRules = 0, failQueries = false;
let holdList;
const originalParse = parser.parse.bind(parser);
parser.parse = content => { parsedRules++; return originalParse(content); };
repository.ensureStore = async () => ({ querySql: async (sql, args) => {
  if (args) {
    assert.match(sql, /WHERE source_url = \? LIMIT 1/);
    pointReads++;
  } else fullReads++;
  if (failQueries) throw new Error('fixture database unavailable');
  const result = args ? (rows.has(args[0]) ? [rows.get(args[0])] : []) : [...rows.values()];
  if (!args && holdList) await holdList;
  let index = -1;
  return {
    goToFirstRow: () => { index = 0; return result.length > 0; },
    goToNextRow: () => ++index < result.length,
    getString: column => String(result[index][column]),
    getLong: column => Number(result[index][column]), close() {}
  };
} });
const resetCounts = () => { fullReads = 0; pointReads = 0; parsedRules = 0; };
const homeText = read('pages/HomePage');
const homeLoad = homeText.slice(homeText.indexOf('  private async loadHomeBlocks('),
  homeText.indexOf('  private scrollContentToTop('));
const menuLoad = homeText.slice(homeText.indexOf('  private filterHomeSources('),
  homeText.indexOf('  private homeSourceMenuOptions('));
const { HomeHarness } = compile(`export class HomeHarness { ${homeLoad}\n${menuLoad} }`, {
  HomeSourceService: homeService, SourceDataService: sources, $r: value => value,
  CoverPrefetcher: { prefetchMany() {} }, hilog: { error() {} }, DOMAIN: 0, TAG: 'test',
  HomeLayoutReadyFrame: class { constructor(callback) { this.callback = callback; } },
  ScrollAlign: { START: 0, CENTER: 1 }
});
homeService.loadHome = async () => ({ blocks: [], categories: [], loadedAt: Date.now() });
const home = Object.assign(new HomeHarness(), {
  homeGen: 0, homeSources: [], homeBlocks: [], homeCategories: [],
  homeNeedsAnySource: false, homeNeedsKindSource: false, homeResolved: false, homeError: '',
  homeContentKind: 1, homeSourcesRevision: -1, homeSourceMenuSerial: 0, homeSourceKeyword: '',
  homeSourceMenuVisible: true, loadingHomeSources: false,
  categoryDS: { setBooks() {} }, onScrollerReady() {},
  updateHomeBlocks(value) { this.homeBlocks = value; },
  updateHomeCategories(value) { this.homeCategories = value; },
  homeSourceMenuData: { setItems() {} },
  homeSourceMenuScroller: { scrollTo() {}, scrollToIndex() {} },
  getUIContext: () => ({ postFrameCallback: frame => frame.callback() }), showHomeSourceToast() {}
});
const shelfText = read('pages/FavoritePage');
const shelfLoad = shelfText.slice(shelfText.indexOf('  async loadFavorites()'),
  shelfText.indexOf('  private async refreshTextProgress()'));
const { ShelfHarness } = compile(`export class ShelfHarness { ${shelfLoad} }`, {
  BookPresentation: { groups: [] },
  setTimeout, clearTimeout,
  SourceDataService: sources, PreferenceService: preferences,
  DataService: { getBooks: async () => books }
});
const shelf = Object.assign(new ShelfHarness(), {
  context: {}, favoritesLoadSerial: 0, selectedBookIds: new Set(), visible: false,
  alive: true, sourceNames: new Map(),
  initialLoadTimer: -1, scheduleAutoUpdate() {},
  isMissingCachedBook: () => false, buildChapterIndexMap: async () => ({}),
  refreshTextProgress: async () => {}, filteredBooks: value => value,
  bookDataSource: { setBooks() {} }
});

(async () => {
  const timers = new Map();
  let timerId = 0, loads = 0, progressReads = 0, updates = 0, completeLoad;
  const visibilityCode = shelfText.slice(shelfText.indexOf('  onVisibleChange()'),
    shelfText.indexOf('  private syncShelfSourceVisibility()'));
  const { VisibilityHarness } = compile(`export class VisibilityHarness { ${visibilityCode} }`, {
    ShelfUpdateService: { shouldAutoCheck: () => updates === 0 },
    setTimeout: callback => { timers.set(++timerId, callback); return timerId; },
    clearTimeout: id => timers.delete(id)
  });
  const visibility = Object.assign(new VisibilityHarness(), {
    alive: true, visible: true, foreground: true, loading: true,
    initialLoadTimer: -1, initialLoadRunning: false, autoUpdateTimer: -1,
    syncShelfSourceVisibility() {}, exitManagement() {},
    loadFavorites: () => { loads++; return new Promise(resolve => { completeLoad = resolve; }); },
    refreshTextProgress: () => { progressReads++; }, refreshOnlineBooks: () => { updates++; }
  });
  visibility.scheduleInitialLoad();
  visibility.onVisibleChange();
  assert.equal(timers.size, 1, 'Appear and visible must share the initial load');
  const initial = timers.get(visibility.initialLoadTimer);
  timers.clear(); initial();
  visibility.onVisibleChange();
  assert.equal(loads, 1, 'visibility must not duplicate an in-flight load');
  assert.equal(timers.size, 0);
  completeLoad();
  await new Promise(resolve => setImmediate(resolve));
  visibility.loading = false;
  for (let i = 0; i < 20; i++) {
    visibility.visible = true; visibility.onVisibleChange();
    visibility.visible = false; visibility.onVisibleChange();
  }
  assert.equal(progressReads, 0, 'warm tab switching uses progress already updated by save events');
  assert.equal(timers.size, 0, 'leaving the shelf cancels pending automatic checks');
  assert.equal(updates, 0, 'rapid switching must not launch an automatic update');
  visibility.visible = true; visibility.onVisibleChange();
  timers.get(visibility.autoUpdateTimer)(); timers.clear();
  assert.equal(updates, 1, 'a settled visible shelf can check updates');
  visibility.visible = false; visibility.onVisibleChange();
  visibility.visible = true; visibility.onVisibleChange();
  assert.equal(timers.size, 0, 'a completed daily check schedules no work on warm tab switches');
  console.log('PASS shelf lifecycle: coalesced initialization, no progress reload on tab switches, cancelled delayed updates');

  const baselineStart = performance.now();
  assert.equal((await sources.getSources()).length, 2000);
  const baselineMs = performance.now() - baselineStart;
  assert.equal(parsedRules, 2000);
  sources.invalidateLocalSources();
  resetCounts();
  await home.loadHomeBlocks();
  await shelf.loadFavorites();
  await shelf.loadSourceNames(books, shelf.favoritesLoadSerial);
  assert.equal(fullReads, 0, 'home and shelf initialization must not scan all rules');
  assert.equal(pointReads, 3, 'only three distinct sources referenced by the pages are queried');
  assert.equal(parsedRules, 3);
  assert.equal(shelf.sourceNames.get(sourceUrl(1888)), 'Source 1888', 'disabled sources still resolve favorites');
  assert.equal(home.currentSource.bookSourceUrl, sourceUrl(1999));

  resetCounts();
  const warmStart = performance.now();
  for (let i = 0; i < 20; i++) {
    await home.loadHomeBlocks(true);
    await shelf.loadFavorites();
  }
  const warmMs = performance.now() - warmStart;
  assert.equal(fullReads + pointReads, 0, 'repeated page loading uses the existing source lookup cache');
  assert.equal(parsedRules, 0, 'Tab changes must not reparse rule JSON');
  console.log(`PASS 2000-source fixture: old full load ${baselineMs.toFixed(1)} ms / 2000 parses; ` +
    `20 repeated page loads ${warmMs.toFixed(1)} ms / 0 reads / 0 parses (host, not device FPS)`);

  await home.loadHomeSourceMenu();
  assert.equal(fullReads, 1, 'the full list is loaded only when opening the source menu');
  // 切源菜单仅列当前分段（有声=奇数 type）发现源；1888 为禁用文本源不在列。
  assert.equal(home.homeSourceMatchCount, 1000, 'menu lists only current content-kind sources');
  assert.equal(home.homeSources[home.homeSourceIndex].bookSourceUrl, preferredUrl);
  home.filterHomeSources(' SOURCE 1111 ');
  assert.equal(home.homeSourceMatchCount, 1);
  await home.loadHomeSourceMenu();
  assert.equal(home.homeSourceMatchCount, 1000, 'reopening clears the filter');
  assert.equal(fullReads, 1, 'unchanged menu options are reused');

  rows.get(sourceUrl(1111))[1] = 'Renamed source';
  sources.invalidateLocalSources(sourceUrl(1111));
  await shelf.loadFavorites();
  await shelf.loadSourceNames(books, shelf.favoritesLoadSerial);
  assert.equal(shelf.sourceNames.get(sourceUrl(1111)), 'Renamed source');
  await home.loadHomeSourceMenu();
  assert.equal(fullReads, 2, 'source changes invalidate the menu list');

  rows.delete(sourceUrl(1999));
  sources.invalidateLocalSources(sourceUrl(1999));
  await home.loadHomeBlocks();
  await shelf.loadFavorites();
  await shelf.loadSourceNames(books, shelf.favoritesLoadSerial);
  assert.equal(home.homeNeedsAnySource, false, 'a deleted selected source falls back to another discovery source');
  assert.equal(home.homeNeedsKindSource, false, 'audio kind still has eligible sources after delete');
  assert.ok(home.currentSource && home.currentSource.bookSourceUrl !== sourceUrl(1999));
  assert.equal(shelf.favoriteBooks.length, 5, 'deleting a source retains existing favorites');
  assert.equal(shelf.sourceNames.has(sourceUrl(1999)), false);
  preferredUrl = sourceUrl(1888);
  homeUrlAudio = sourceUrl(1888);
  const migrated = await homeService.getSelectedSource(1);
  assert.notEqual(migrated?.bookSourceUrl, sourceUrl(1888), 'disabled text source cannot power audio home');
  assert.ok(migrated, 'disabled preference migrates to another eligible source');

  sources.invalidateLocalSources();
  let release;
  holdList = new Promise(resolve => { release = resolve; });
  const pending = home.loadHomeSourceMenu();
  await home.loadHomeSourceMenu();
  sources.invalidateLocalSources();
  release();
  await pending;
  holdList = undefined;
  assert.equal(home.loadingHomeSources, false);
  assert.notEqual(home.homeSourcesRevision, sources.getInvalidationCounter(), 'late list is not cached as current');
  await home.loadHomeSourceMenu();
  assert.equal(home.homeSourcesRevision, sources.getInvalidationCounter());

  sources.invalidateLocalSources();
  failQueries = true;
  await home.loadHomeSourceMenu();
  assert.equal(home.loadingHomeSources, false, 'database failure releases the menu spinner');
  failQueries = false;
  await home.loadHomeSourceMenu();
  assert.equal(home.homeSourceMatchCount, 999, 'a failed menu load can retry');
  books = [];
  sources.invalidateLocalSources();
  resetCounts();
  for (const url of ['', legacyRankingUrl]) {
    preferredUrl = url;
    homeUrlAudio = url;
    homeUrlText = '';
    homeContentKind = 0;
    await home.loadHomeBlocks();
    assert.equal(home.homeNeedsAnySource, false, 'empty or legacy ranking preference migrates to an available source');
    assert.ok(home.currentSource);
  }
  // 清空全部书源后才进入无源引导。
  rows.clear();
  sources.invalidateLocalSources();
  preferredUrl = '';
  homeUrlAudio = '';
  homeUrlText = '';
  homeContentKind = 1;
  resetCounts();
  await home.loadHomeBlocks();
  assert.equal(home.homeNeedsAnySource, true, 'no eligible discovery source shows the add-source guide');
  assert.equal(home.homeNeedsKindSource, true, 'empty database marks current kind empty');
  assert.equal(parsedRules, 0, 'empty home guide parses no rule JSON');
  resetCounts();
  await shelf.loadFavorites();
  assert.equal(fullReads + pointReads + parsedRules, 0, 'empty shelf needs no imported rules');
  console.log('PASS menu lazy loading/filter/reuse/invalidation/retry, disabled/deleted sources and empty shelf');
})().catch(error => { console.error(error); process.exitCode = 1; });
