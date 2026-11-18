const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const ide = process.env.DEVECO_HOME;
if (!ide) throw new Error('Set DEVECO_HOME to the Release IDE');
const ts = require(path.join(ide, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
const etsRoot = path.join(__dirname, '../entry/src/main/ets');
const themeKey = 'app_theme_preferences';
const realModules = new Set([
  'model/AppAppearance', 'model/AppThemeBundle', 'theme/ThemeBundles', 'service/PreferenceService',
  'service/ThemeBackgroundService'
]);
const compiled = new Map();

function compile(name) {
  if (!compiled.has(name)) {
    const source = fs.readFileSync(path.join(etsRoot, name + '.ets'), 'utf8');
    compiled.set(name, ts.transpileModule(source, { compilerOptions: {
      target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS, experimentalDecorators: true
    } }).outputText);
  }
  return compiled.get(name);
}

function createDisk(entries = []) {
  return { values: new Map(entries) };
}

async function launch(disk) {
  const cache = new Map(disk.values);
  const controls = { failFlush: false, beforeFlush: undefined };
  const store = {
    getSync: (key, fallback) => cache.has(key) ? cache.get(key) : fallback,
    get: async (key, fallback) => cache.has(key) ? cache.get(key) : fallback,
    getAll: async () => Object.fromEntries(cache),
    put: async (key, value) => { cache.set(key, value); },
    delete: async key => { cache.delete(key); },
    flush: async () => {
      await controls.beforeFlush?.();
      if (controls.failFlush) throw new Error('simulated disk full');
      disk.values = new Map(cache);
    }
  };
  const mocks = {
    '@kit.ArkData': { preferences: { getPreferences: async () => store } },
    '@kit.AbilityKit': { ConfigurationConstant: { ColorMode: { COLOR_MODE_NOT_SET: -1 } }, common: {} },
    '@kit.BasicServicesKit': { emitter: { emit: () => {} } },
    '@kit.MediaLibraryKit': { photoAccessHelper: {} },
    '@kit.CoreFileKit': { fileIo: { access: async () => false, mkdir: async () => {}, listFile: async () => [],
      unlink: async () => {}, open: async () => ({ fd: 1 }), close: async () => {}, copyFile: async () => {},
      stat: async () => ({ size: 1 }) } },
    '@kit.ImageKit': { image: { createImageSource: () => ({ getImageInfo: async () => ({}), release: async () => {} }) } },
    '../model/GeneralSettings': { GeneralSettings: { current: {} } },
    '../model/BookPresentation': { BookPresentation: { edits: [], groups: [] } },
    './ReadingSessionService': { ReadingSessionService: { init: () => {} } },
    '../model/Book': {}
  };
  const context = vm.createContext({
    console, Error, ObservedV2: value => value, Trace: () => {}, $r: name => ({ id: name })
  });
  const modules = new Map();
  function load(name) {
    if (modules.has(name)) return modules.get(name);
    assert.ok(realModules.has(name), `Unexpected ETS dependency: ${name}`);
    const exports = {};
    modules.set(name, exports);
    const localRequire = request => {
      if (Object.hasOwn(mocks, request)) return mocks[request];
      const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(name), request));
      return load(resolved);
    };
    vm.runInContext(`(function(exports, require) {\n${compile(name)}\n})`, context,
      { filename: name + '.ets' })(exports, localRequire);
    return exports;
  }
  const preference = load('service/PreferenceService');
  const appearance = load('model/AppAppearance').AppAppearance.current;
  await preference.PreferenceService.init({ filesDir: '/tmp/theme-test' });
  return {
    service: preference.PreferenceService, Snapshot: preference.PreferenceBackupSnapshot,
    Selection: load('model/AppThemeBundle').AppThemeSelection,
    bundles: load('theme/ThemeBundles').ThemeBundles, appearance, cache, controls, disk
  };
}

function appearanceOf(app) {
  return [app.appearance.themeBundleId, app.appearance.accent, app.appearance.material,
    app.appearance.backgroundColor, app.appearance.surfaceColor, app.appearance.textColor,
    app.appearance.customBackgroundName];
}

function storedSelection(app) {
  return JSON.parse(app.disk.values.get(themeKey));
}

function expectedSelection(accent, material, background = '', surface = '', text = '', bgName = '') {
  return {
    schemaVersion: 2,
    themeBundleId: 'ginkgo-winter',
    accentColor: accent,
    materialStyle: material,
    backgroundColor: background,
    surfaceColor: surface,
    textColor: text,
    customBackgroundName: bgName
  };
}

(async () => {
  const ginkgoId = 'ginkgo-winter';
  const ginkgoAccent = '#E8B02E';
  const disk = createDisk([['accent_color', '#123abc'], ['material_style', 5]]);
  let app = await launch(disk);
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#123ABC', 4, '', '', '', ''],
    'legacy custom appearance migrates onto ginkgo');
  assert.equal(disk.values.has(themeKey), false, 'initialization does not overwrite legacy preferences');

  const ginkgo = app.bundles.resolve(ginkgoId);
  let startFlush;
  let finishFlush;
  const flushing = new Promise(resolve => { startFlush = resolve; });
  const releaseFlush = new Promise(resolve => { finishFlush = resolve; });
  app.controls.beforeFlush = async () => { startFlush(); await releaseFlush; };
  const apply = app.service.applyThemeBundle(ginkgo.id);
  await flushing;
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#123ABC', 4, '', '', '', ''],
    'publish only after successful persistence');
  finishFlush();
  await apply;
  app.controls.beforeFlush = undefined;
  assert.deepEqual(appearanceOf(app), [ginkgoId, ginkgo.accent, ginkgo.material, '', '', '', '']);
  assert.deepEqual(storedSelection(app), expectedSelection(ginkgo.accent, ginkgo.material));

  await Promise.all([
    app.service.applyThemeBundle(ginkgoId),
    app.service.setAccentColor('#2255aa'),
    app.service.setMaterialStyle(4)
  ]);
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#2255AA', 4, '', '', '', ''],
    'queued changes keep every selected field');
  assert.deepEqual(storedSelection(app), expectedSelection('#2255AA', 4));
  app = await launch(disk);
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#2255AA', 4, '', '', '', ''],
    'fresh process restores the complete selection');

  await app.service.setThemePalette('#EAF4F0', '#FFF8E8', '#3A2E14', '#E8B02E');
  assert.equal(app.appearance.accent, ginkgoAccent);

  await app.service.setThemePalette('#112233', '#445566', '#778899', '#AABBCC');
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#AABBCC', 4, '#112233', '#445566', '#778899', '']);
  assert.deepEqual(storedSelection(app), expectedSelection('#AABBCC', 4, '#112233', '#445566', '#778899'));

  const beforeFailure = disk.values.get(themeKey);
  app.controls.failFlush = true;
  await assert.rejects(app.service.applyThemeBundle(ginkgoId), /disk full/);
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#AABBCC', 4, '#112233', '#445566', '#778899', ''],
    'failed apply keeps the visible theme');
  assert.equal(app.cache.get(themeKey), beforeFailure, 'failed apply rolls back the Preferences cache');
  assert.equal(disk.values.get(themeKey), beforeFailure);
  app.controls.failFlush = false;
  await app.service.setDefaultTab(2);
  assert.equal(disk.values.get(themeKey), beforeFailure, 'an unrelated successful flush cannot persist the failed theme');
  await app.service.setMaterialStyle(2);
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#AABBCC', 2, '#112233', '#445566', '#778899', ''],
    'a failed write does not poison the save queue');
  await assert.rejects(app.service.applyThemeBundle('paper-study'), /Unknown theme/);
  assert.deepEqual(appearanceOf(app), [ginkgoId, '#AABBCC', 2, '#112233', '#445566', '#778899', '']);

  for (const raw of ['{broken', 'null', '[]', '{"schemaVersion":3}', 'x'.repeat(4097)]) {
    const invalid = await launch(createDisk([
      ['accent_color', '#123ABC'], ['material_style', 2], [themeKey, raw]
    ]));
    assert.deepEqual(appearanceOf(invalid), [ginkgoId, '#123ABC', 2, '', '', '', ''],
      'invalid stored records fall back to legacy settings on ginkgo');
  }
  const unknown = await launch(createDisk([[themeKey,
    JSON.stringify({ schemaVersion: 1, themeBundleId: 'removed-theme', accentColor: '#335577',
      materialStyle: 4 })]]));
  assert.deepEqual(appearanceOf(unknown), [ginkgoId, '#335577', 4, '', '', '', ''],
    'unknown bundles migrate onto ginkgo and retain accent');
  const invalidOverrides = await launch(createDisk([[themeKey,
    JSON.stringify({ schemaVersion: 1, themeBundleId: 'paper-study', accentColor: 'invalid-color',
      materialStyle: 99 })]]));
  assert.deepEqual(appearanceOf(invalidOverrides), [ginkgoId, ginkgoAccent, 3, '', '', '', ''],
    'invalid accent falls back to ginkgo accent');

  const snapshot = await app.service.exportBackupSnapshot();
  assert.ok(snapshot.themeSelection instanceof app.Selection, 'export uses the real selection data carrier');
  assert.deepEqual(JSON.parse(JSON.stringify(snapshot.themeSelection)),
    expectedSelection('#AABBCC', 2, '#112233', '#445566', '#778899'));
  const restored = await launch(createDisk());
  await restored.service.restoreBackupSnapshot(JSON.parse(JSON.stringify(snapshot)));
  assert.deepEqual(appearanceOf(restored), [ginkgoId, '#AABBCC', 2, '#112233', '#445566', '#778899', '']);
  assert.deepEqual(appearanceOf(await launch(restored.disk)),
    [ginkgoId, '#AABBCC', 2, '#112233', '#445566', '#778899', ''], 'restored snapshot survives restart');

  const legacy = new restored.Snapshot();
  legacy.accentColor = '#778899';
  legacy.materialStyle = 4;
  await restored.service.restoreBackupSnapshot(legacy);
  assert.deepEqual(appearanceOf(restored), [ginkgoId, '#778899', 4, '', '', '', ''],
    'pre-theme backup defaults to ginkgo and preserves overrides');
  assert.deepEqual(storedSelection(restored), expectedSelection('#778899', 4));
  await restored.service.restoreBackupSnapshot(new restored.Snapshot());
  assert.deepEqual(appearanceOf(restored), [ginkgoId, ginkgoAccent, 3, '', '', '', ''],
    'old backup without appearance preferences gets ginkgo defaults');

  const failedRestore = await launch(createDisk([['accent_color', '#123ABC'], ['material_style', 4]]));
  failedRestore.controls.failFlush = true;
  await assert.rejects(failedRestore.service.restoreBackupSnapshot(JSON.parse(JSON.stringify(snapshot))),
    /disk full/);
  assert.deepEqual(appearanceOf(failedRestore), [ginkgoId, '#123ABC', 4, '', '', '', ''],
    'failed restore keeps the current appearance');
  failedRestore.controls.failFlush = false;
  await failedRestore.service.setDefaultTab(1);
  assert.deepEqual(appearanceOf(await launch(failedRestore.disk)), [ginkgoId, '#123ABC', 4, '', '', '', ''],
    'failed restore must roll back legacy appearance keys before an unrelated flush');

  console.log('PASS: ginkgo-only theme, custom palette, flush rollback, restart, invalid records and backup compatibility');
})().catch(error => { console.error(error); process.exitCode = 1; });
