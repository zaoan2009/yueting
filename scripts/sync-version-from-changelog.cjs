#!/usr/bin/env node
/**
 * 仅根据已有 CHANGELOG.md 同步版本与关于页数据（不升版）。
 * 自动升版请用：node scripts/bump-version.cjs
 */
'use strict';

const { syncFromChangelogFile } = require('./lib/version-from-changelog.cjs');

const { versionName, versionCode, releases } = syncFromChangelogFile();
console.log(`已同步版本 ${versionName} (versionCode ${versionCode})，共 ${releases.length} 个版本记录`);
