const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(path.join(process.env.DEVECO_HOME,
  'sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript'));
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/utils/SearchOptions.ets'), 'utf8');
const code = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText;
const exportsObject = {};
vm.runInNewContext(code, { exports: exportsObject });
const { SearchOptions } = exportsObject;
for (let mask = 0; mask < 4; mask++) {
  const textOnly = Boolean(mask & 1);
  const audioOnly = Boolean(mask & 2);
  for (const [sourceType, contentType, expectText, expectAudio] of [
    [0, 'text', true, false], [3, 'text', true, false], [1, 'audio', false, true], [2, 'comic', false, false]
  ]) {
    const expected = (!textOnly && !audioOnly) || (textOnly && expectText) || (audioOnly && expectAudio);
    assert.equal(SearchOptions.matchesSourceType(sourceType, textOnly, audioOnly), expected,
      `sourceType=${sourceType} mask=${mask}`);
    assert.equal(SearchOptions.matchesContentType(contentType, textOnly, audioOnly), expected,
      `contentType=${contentType} mask=${mask}`);
  }
  assert.equal(SearchOptions.matchesSourceType(undefined, textOnly, audioOnly), !textOnly && !audioOnly);
}
assert.equal(SearchOptions.matchesSourceType(2, false, false), true);
assert.equal(SearchOptions.matchesContentType('comic', true, false), false);
assert.equal(SearchOptions.matchesContentType('comic', false, true), false);
console.log('PASS: search type combinations; comic is never matched by text/audio filters');
