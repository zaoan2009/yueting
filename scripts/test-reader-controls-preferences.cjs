const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ide = process.env.DEVECO_HOME;
if (!ide) throw new Error('Set DEVECO_HOME to the Release IDE');
const ts = require(path.join(ide, 'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/service/PreferenceService.ets'), 'utf8');
const code = ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS
} }).outputText;
const values = new Map([['reader_brightness', 0.73], ['showBrightnessBar', true]]);
const state = { adaptiveHandedness: true };
let failFlush = false;
const store = {
  getSync: (key, fallback) => values.get(key) ?? fallback,
  put: async (key, value) => values.set(key, value),
  flush: async () => { if (failFlush) throw new Error('disk full'); }
};
function load() {
  const exports = {};
  vm.runInNewContext(code, { exports, require: name => name === '../model/GeneralSettings' ?
    { GeneralSettings: { current: state } } : {} });
  exports.PreferenceService.store = store;
  return exports.PreferenceService;
}
(async () => {
  const service = load();
  assert.equal(typeof service.getComicVolumeKeyPageTurn, 'undefined', 'comic preferences removed');
  assert.equal(typeof service.setComicReadingMode, 'undefined');
  assert.equal(typeof service.getComicBrightness, 'undefined');
  assert.equal(typeof service.getSearchComicOnly, 'undefined');
  await service.setAdaptiveHandedness(false);
  assert.equal(state.adaptiveHandedness, false);
  assert.equal(values.get('adaptive_handedness'), false);
  failFlush = true;
  await assert.rejects(service.setAdaptiveHandedness(true));
  assert.equal(state.adaptiveHandedness, false);
  assert.equal(values.get('adaptive_handedness'), false);
  failFlush = false;
  await service.setAdaptiveHandedness(true);
  assert.equal(state.adaptiveHandedness, true);
  console.log('PASS: comic preferences removed; adaptive handedness save/rollback still works');
})().catch(error => { console.error(error); process.exitCode = 1; });
