'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const CHANGELOG = path.join(ROOT, 'CHANGELOG.md');

function parseChangelog(text) {
  const lines = text.split(/\r?\n/);
  /** @type {{ version: string, items: string[] }[]} */
  const releases = [];
  let current = null;
  for (const raw of lines) {
    const line = raw.trimEnd();
    const heading = line.match(/^##\s+v?(\d+\.\d+\.\d+)\s*$/i);
    if (heading) {
      current = { version: heading[1], items: [] };
      releases.push(current);
      continue;
    }
    if (!current) continue;
    const item = line.match(/^-\s+(.+)$/);
    if (item) current.items.push(item[1].trim());
  }
  if (releases.length === 0) {
    throw new Error('CHANGELOG.md 未找到 ## vX.Y.Z 版本节');
  }
  return releases;
}

function versionCodeOf(versionName) {
  const parts = versionName.split('.').map((p) => Number(p));
  if (parts.length !== 3 || parts.some((n) => !Number.isInteger(n) || n < 0 || n > 99)) {
    throw new Error(`无法解析 versionName: ${versionName}`);
  }
  return parts[0] * 10000 + parts[1] * 100 + parts[2];
}

function bumpSemver(versionName, level) {
  const parts = versionName.split('.').map((p) => Number(p));
  if (level === 'major') {
    return `${parts[0] + 1}.0.0`;
  }
  if (level === 'minor') {
    return `${parts[0]}.${parts[1] + 1}.0`;
  }
  return `${parts[0]}.${parts[1]}.${parts[2] + 1}`;
}

function replaceJson5Field(source, key, value) {
  const re = new RegExp(`("${key}"\\s*:\\s*)(?:"[^"]*"|\\d+)`);
  if (!re.test(source)) {
    throw new Error(`未找到字段 ${key}`);
  }
  const literal = typeof value === 'number' ? String(value) : JSON.stringify(value);
  return source.replace(re, `$1${literal}`);
}

function writeAppJson5(versionName, versionCode) {
  const file = path.join(ROOT, 'AppScope/app.json5');
  let text = fs.readFileSync(file, 'utf8');
  text = replaceJson5Field(text, 'versionCode', versionCode);
  text = replaceJson5Field(text, 'versionName', versionName);
  text = replaceJson5Field(text, 'buildVersion', String(versionCode));
  fs.writeFileSync(file, text);
}

function writeOhPackage(versionName) {
  const file = path.join(ROOT, 'oh-package.json5');
  let text = fs.readFileSync(file, 'utf8');
  text = replaceJson5Field(text, 'version', versionName);
  fs.writeFileSync(file, text);
}

function writeGallery(releases) {
  const file = path.join(ROOT, 'docs/app-gallery/zh-CN.json');
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const latest = releases[0];
  data.versionName = latest.version;
  data.versionCode = versionCodeOf(latest.version);
  data.releaseNotes = latest.items.map((item) => `- ${item}`).join('\n');
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

function writeRawChangelog(releases) {
  const out = path.join(ROOT, 'entry/src/main/resources/rawfile/changelog.json');
  const payload = {
    generatedFrom: 'CHANGELOG.md',
    releases: releases.map((r) => ({
      version: r.version,
      items: r.items
    }))
  };
  fs.writeFileSync(out, `${JSON.stringify(payload, null, 2)}\n`);
}

function writeClaude(versionName, versionCode) {
  const file = path.join(ROOT, 'CLAUDE.md');
  const text = fs.readFileSync(file, 'utf8');
  const exact = /当前 `versionName = [^`]+`、`versionCode = [^`]+`/;
  const loose = /(`versionName = )[^`]+(`、`versionCode = )[^`]+(`)/;
  let next = text;
  if (exact.test(text)) {
    next = text.replace(exact, `当前 \`versionName = ${versionName}\`、\`versionCode = ${versionCode}\``);
  } else if (loose.test(text)) {
    next = text.replace(loose, `$1${versionName}$2${versionCode}$3`);
  } else {
    console.warn('CLAUDE.md 未找到 versionName/versionCode 行，已跳过');
    return;
  }
  if (next !== text) fs.writeFileSync(file, next);
}

function writeIntroduction(releases) {
  const file = path.join(ROOT, 'docs/app-gallery/introduction.txt');
  if (!fs.existsSync(file)) return;
  const latest = releases[0];
  const notes = latest.items.map((item) => `- ${item}`).join('\n');
  let text = fs.readFileSync(file, 'utf8');
  if (/新版本说明/.test(text)) {
    text = text.replace(/新版本说明[\s\S]*$/m, `新版本说明\n${notes}\n`);
  } else {
    text = `${text.trimEnd()}\n\n新版本说明\n${notes}\n`;
  }
  fs.writeFileSync(file, text.endsWith('\n') ? text : `${text}\n`);
}

function prependChangelog(versionName, items) {
  const existing = fs.readFileSync(CHANGELOG, 'utf8');
  const body = items.map((item) => `- ${item}`).join('\n');
  const section = `## v${versionName}\n\n${body}\n`;
  let next;
  if (/^#\s*更新日志\s*$/m.test(existing)) {
    next = existing.replace(/^(#\s*更新日志\s*\n+)/m, `$1${section}\n`);
  } else {
    next = `# 更新日志\n\n${section}\n${existing}`;
  }
  fs.writeFileSync(CHANGELOG, next.endsWith('\n') ? next : `${next}\n`);
}

function syncFromChangelogFile() {
  const releases = parseChangelog(fs.readFileSync(CHANGELOG, 'utf8'));
  const latest = releases[0];
  const versionName = latest.version;
  const versionCode = versionCodeOf(versionName);
  writeAppJson5(versionName, versionCode);
  writeOhPackage(versionName);
  writeGallery(releases);
  writeRawChangelog(releases);
  writeClaude(versionName, versionCode);
  writeIntroduction(releases);
  return { versionName, versionCode, releases };
}

module.exports = {
  ROOT,
  CHANGELOG,
  parseChangelog,
  versionCodeOf,
  bumpSemver,
  prependChangelog,
  syncFromChangelogFile
};
