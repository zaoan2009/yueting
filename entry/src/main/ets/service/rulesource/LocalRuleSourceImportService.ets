import { LocalRuleSource } from '../../model/LocalRuleSource';
import { Chapter } from '../../model/Book';
import { SearchCache } from '../../utils/SearchCache';
import { DataService } from '../DataService';
import { ChapterCacheService } from '../ChapterCacheService';
import { SourceDataService } from '../SourceDataService';
import { BookSourceService } from '../BookSourceService';
import { LocalRuleSourceRepository } from './LocalRuleSourceRepository';

/** 用户导入入口：成功写入后清理被覆盖来源的可再获取缓存。 */
export class LocalRuleSourceImportService {
  static async importSources(sources: LocalRuleSource[],
    overwriteLocked: boolean = false): Promise<number> {
    const existing = await LocalRuleSourceRepository.getAll();
    const existingByUrl = new Map<string, LocalRuleSource>();
    for (const source of existing) {
      existingByUrl.set(source.bookSourceUrl.trim(), source);
    }
    const replaced = new Set<string>();
    for (const source of sources) {
      const url = source.bookSourceUrl.trim();
      if (url.length === 0) continue;
      const previous = existingByUrl.get(url);
      if (previous === undefined) continue;
      if (previous.isLocked && !overwriteLocked) continue;
      replaced.add(url);
    }
    const count = await LocalRuleSourceRepository.upsertImportedBatch(sources, overwriteLocked);
    SourceDataService.invalidateLocalSources();
    if (replaced.size > 0) {
      BookSourceService.invalidateAudioTocs(replaced);
      const cache = ChapterCacheService.getInstance();
      cache.suspendPreload();
      try {
        const protectedIds = await DataService.historyBookIds();
        const clearAudio = (bookId: string, chapters: Chapter[]): void => {
          if (protectedIds !== null && !protectedIds.has(bookId)) cache.clearBook(bookId, chapters);
        };
        if (protectedIds !== null) SearchCache.invalidateSources(replaced, clearAudio, protectedIds);
        await DataService.invalidateSourceCaches(replaced, clearAudio);
      } finally {
        cache.resumePreload();
      }
    }
    return count;
  }
}
