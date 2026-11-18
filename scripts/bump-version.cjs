#!/usr/bin/env node
/**
 * 自动升版：推断变更说明 → 写入 CHANGELOG.md → 同步 App / 关于页 / 上架文案。
 *
 * 用法：
 *   node scripts/bump-version.cjs              # 默认 patch，说明来自 git
 *   node scripts/bump-version.cjs --minor
 *   node scripts/bump-version.cjs --major
 *   node scripts/bump-version.cjs --auto       # 按提交前缀推断：breaking→major，feat→minor，其余 patch
 *   node scripts/bump-version.cjs -m "说明1" -m "说明2"
 *   node scripts/bump-version.cjs --dry-run
 */
'use strict';

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const {
  ROOT,
  CHANGELOG,
  parseChangelog,
  bumpSemver,
  prependChangelog,
  syncFromChangelogFile
} = require('./lib/version-from-changelog.cjs');

function runGit(args) {
  try {
    return execSync(`git ${args}`, {
      cwd: ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
  } catch (_error) {
    return '';
  }
}

function parseArgs(argv) {
  /** @type {'patch'|'minor'|'major'|'auto'} */
  let level = 'patch';
  const messages = [];
  let dryRun = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--major') level = 'major';
    else if (arg === '--minor') level = 'minor';
    else if (arg === '--patch') level = 'patch';
    else if (arg === '--auto') level = 'auto';
    else if (arg === '--dry-run') dryRun = true;
    else if (arg === '-m' || arg === '--message') {
      const value = argv[++i];
      if (!value) throw new Error(`${arg} 需要说明文字`);
      messages.push(value.trim());
    } else if (arg.startsWith('-m=')) {
      messages.push(arg.slice(3).trim());
    } else if (arg === '--help' || arg === '-h') {
      console.log(`用法: node scripts/bump-version.cjs [--auto|--patch|--minor|--major] [-m 说明...] [--dry-run]`);
      process.exit(0);
    } else {
      throw new Error(`未知参数: ${arg}`);
    }
  }
  return { level, messages, dryRun };
}

function cleanCommitSubject(subject) {
  return subject
    .replace(/^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?[!]?:\s*/i, '')
    .replace(/^v?\d+\.\d+\.\d+\s*[-:：]\s*/i, '')
    .trim();
}

function inferLevelFromSubjects(subjects) {
  let level = 'patch';
  for (const subject of subjects) {
    if (/breaking change|！|!:/i.test(subject) || /^(feat|fix|perf|refactor)(\(.+\))?!:/i.test(subject)) {
      return 'major';
    }
    if (/^feat(\(.+\))?:/i.test(subject)) {
      level = 'minor';
    }
  }
  return level;
}

function collectGitSubjects(previousVersion) {
  const tag = `v${previousVersion}`;
  const hasTag = runGit(`tag -l ${tag}`) === tag;
  let range = '';
  if (hasTag) {
    range = `${tag}..HEAD`;
  } else {
    // 无 tag 时只取「上次改 CHANGELOG 之后」的提交，避免扫到整仓历史误升 minor。
    const lastChangelog = runGit('log -1 --pretty=format:%H -- CHANGELOG.md');
    if (lastChangelog) range = `${lastChangelog}..HEAD`;
  }
  const logArgs = range
    ? `log ${range} --pretty=format:%s --no-merges`
    : 'log -12 --pretty=format:%s --no-merges';
  const raw = runGit(logArgs);
  if (!raw) return [];
  return raw.split('\n').map((line) => line.trim()).filter(Boolean);
}

function collectChangedAreas() {
  const status = runGit('status --porcelain');
  if (!status) return [];
  /** @type {Set<string>} */
  const areas = new Set();
  for (const line of status.split('\n')) {
    const file = line.slice(3).trim().replace(/ -> /, ' ').split(/\s+/).pop() || '';
    if (!file || file.startsWith('CHANGELOG.md') || file.includes('changelog.json')) continue;
    if (file.startsWith('entry/src/main/ets/pages/PlayerPage')) areas.add('播放页与定时关闭');
    else if (file.startsWith('entry/src/main/ets/pages/AboutPage')
      || file.startsWith('entry/src/main/ets/pages/ChangelogPage')) areas.add('关于页与更新日志');
    else if (file.startsWith('entry/src/main/ets/')) areas.add('应用功能与体验');
    else if (file.startsWith('docs/')) areas.add('文档与上架素材');
    else if (file.startsWith('scripts/')) areas.add('构建与发版脚本');
    else if (file.startsWith('AppScope/') || file === 'oh-package.json5') areas.add('应用版本与工程配置');
  }
  return [...areas].map((area) => `${area}相关更新`);
}

function buildItems(explicitMessages, previousVersion) {
  if (explicitMessages.length > 0) {
    return [...new Set(explicitMessages.filter(Boolean))];
  }
  // 未提交改动优先：更贴近本轮实际工作，而不是旧提交。
  const areas = collectChangedAreas();
  if (areas.length > 0) return areas;
  const subjects = collectGitSubjects(previousVersion);
  const fromCommits = [];
  /** @type {Set<string>} */
  const seen = new Set();
  for (const subject of subjects) {
    if (/^v?\d+\.\d+\.\d+$/i.test(subject)) continue;
    if (/sync-version|bump-version|changelog|升版|版本号/i.test(subject)) continue;
    const cleaned = cleanCommitSubject(subject);
    if (!cleaned || seen.has(cleaned)) continue;
    seen.add(cleaned);
    fromCommits.push(cleaned.endsWith('。') ? cleaned : `${cleaned}`);
    if (fromCommits.length >= 8) break;
  }
  if (fromCommits.length > 0) return fromCommits;
  return ['常规更新与修复'];
}

function main() {
  const { level: requestedLevel, messages, dryRun } = parseArgs(process.argv.slice(2));
  const releases = parseChangelog(fs.readFileSync(CHANGELOG, 'utf8'));
  const previousVersion = releases[0].version;
  const dirtyAreas = collectChangedAreas();
  const subjects = collectGitSubjects(previousVersion);
  // 有未提交改动时 --auto 默认 patch，避免被历史 feat 提交抬到 minor。
  const level = requestedLevel === 'auto'
    ? (dirtyAreas.length > 0 ? 'patch' : inferLevelFromSubjects(subjects))
    : requestedLevel;
  const nextVersion = bumpSemver(previousVersion, level);
  if (nextVersion === previousVersion) {
    throw new Error('版本未变化');
  }
  const items = buildItems(messages, previousVersion);
  if (dryRun) {
    console.log(JSON.stringify({
      previousVersion,
      nextVersion,
      level,
      items
    }, null, 2));
    return;
  }
  prependChangelog(nextVersion, items);
  const synced = syncFromChangelogFile();
  console.log(`已自动升版 ${previousVersion} → ${synced.versionName} (versionCode ${synced.versionCode}, ${level})`);
  for (const item of items) {
    console.log(`  - ${item}`);
  }
}

main();
