import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LocalRuleSource } from '../../model/LocalRuleSource';
import { CharsetCodec } from '../../utils/CharsetCodec';
import { EVT_HOME_SOURCE_CHANGED, PreferenceService } from '../PreferenceService';
import { SourceDataService } from '../SourceDataService';
import { emitter } from '@kit.BasicServicesKit';
import { LocalRuleSourceImportParser } from './LocalRuleSourceImportParser';
import { LocalRuleSourceImportService } from './LocalRuleSourceImportService';
import { LocalRuleSourceRepository } from './LocalRuleSourceRepository';

const DOMAIN: number = 0x3200;
const TAG: string = 'DefaultRuleSource';
const AUDIO_RAW_FILE: string = 'default_audio_sources.json';
const TEXT_RAW_FILE: string = 'default_text_sources.json';

/**
 * 包内示例规则：不再自动安装。
 * 升级时按听书 rawfile URL 白名单一次性清除旧预置听书源；
 * 关于页图标连点可载入听书 + 电子书示例。
 */
export class DefaultRuleSourceService {
  private static purgeTask: Promise<void> | null = null;

  /** 启动时调用：仅执行一次预置听书源清理。 */
  static purgeBundledAudioSourcesOnce(context: common.UIAbilityContext): Promise<void> {
    if (DefaultRuleSourceService.purgeTask !== null) {
      return DefaultRuleSourceService.purgeTask;
    }
    const pending: Promise<void> = DefaultRuleSourceService.runPurge(context).catch((error: Error): void => {
      hilog.warn(DOMAIN, TAG, 'preset purge skipped: %{public}s', error.message);
    }).then((): void => {
      if (DefaultRuleSourceService.purgeTask === pending) {
        DefaultRuleSourceService.purgeTask = null;
      }
    });
    DefaultRuleSourceService.purgeTask = pending;
    return pending;
  }

  /** 关于页隐蔽入口：导入包内听书与电子书示例规则，返回成功写入条数。 */
  static async importSampleSources(context: common.UIAbilityContext): Promise<number> {
    await LocalRuleSourceRepository.init(context);
    const sources: LocalRuleSource[] = await DefaultRuleSourceService.parseSampleFiles(context);
    if (sources.length === 0) {
      throw new Error('sample sources empty');
    }
    // 示例入口默认强制覆盖同地址定义（含锁定），便于规则修复后再次载入。
    const count: number = await LocalRuleSourceImportService.importSources(sources, true);
    SourceDataService.invalidateLocalSources();
    emitter.emit(EVT_HOME_SOURCE_CHANGED);
    hilog.info(DOMAIN, TAG, 'imported %{public}d sample sources', count);
    return count;
  }

  private static async runPurge(context: common.UIAbilityContext): Promise<void> {
    if (await PreferenceService.isPresetAudioSourcesPurged()) {
      return;
    }
    await LocalRuleSourceRepository.init(context);
    const bundled: LocalRuleSource[] = await DefaultRuleSourceService.parseRawFile(context, AUDIO_RAW_FILE);
    const bundledUrls: Set<string> = new Set<string>();
    for (const source of bundled) {
      const url: string = source.bookSourceUrl.trim();
      if (url.length > 0) {
        bundledUrls.add(url);
      }
    }
    if (bundledUrls.size === 0) {
      await PreferenceService.setPresetAudioSourcesPurged(true);
      return;
    }
    const existing: LocalRuleSource[] = await LocalRuleSourceRepository.getAll();
    const toDelete: string[] = [];
    for (const source of existing) {
      if (bundledUrls.has(source.bookSourceUrl.trim())) {
        toDelete.push(source.bookSourceUrl);
      }
    }
    if (toDelete.length > 0) {
      // 预置清理含锁定源：先解锁再批量删除，避免 deleteBatch 跳过锁定项。
      await LocalRuleSourceRepository.setLockedBatch(toDelete, false);
      const deleted: number = await LocalRuleSourceRepository.deleteBatch(toDelete);
      SourceDataService.invalidateLocalSources();
      emitter.emit(EVT_HOME_SOURCE_CHANGED);
      hilog.info(DOMAIN, TAG, 'purged %{public}d preset audio sources', deleted);
    }
    await PreferenceService.setPresetAudioSourcesPurged(true);
  }

  private static async parseSampleFiles(context: common.UIAbilityContext): Promise<LocalRuleSource[]> {
    const audio: LocalRuleSource[] = await DefaultRuleSourceService.parseRawFile(context, AUDIO_RAW_FILE);
    const text: LocalRuleSource[] = await DefaultRuleSourceService.parseRawFile(context, TEXT_RAW_FILE);
    const merged: LocalRuleSource[] = [];
    const seen: Set<string> = new Set<string>();
    for (const source of audio.concat(text)) {
      const url: string = source.bookSourceUrl.trim();
      if (url.length === 0 || seen.has(url)) {
        continue;
      }
      seen.add(url);
      merged.push(source);
    }
    return merged;
  }

  private static async parseRawFile(context: common.UIAbilityContext, fileName: string): Promise<LocalRuleSource[]> {
    try {
      const content: string = await DefaultRuleSourceService.readRawFile(context, fileName);
      const report = LocalRuleSourceImportParser.parse(content);
      if (report.sources.length === 0) {
        hilog.warn(DOMAIN, TAG, 'bundled %{public}s empty: %{public}s', fileName, report.message);
      }
      return report.sources;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'read %{public}s failed: %{public}s', fileName, String(error));
      return [];
    }
  }

  private static async readRawFile(context: common.UIAbilityContext, fileName: string): Promise<string> {
    const bytes: Uint8Array = await context.resourceManager.getRawFileContent(fileName);
    const copy: ArrayBuffer = new ArrayBuffer(bytes.byteLength);
    new Uint8Array(copy).set(bytes);
    return CharsetCodec.decodeBuffer(copy);
  }
}
