import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { emitter } from '@kit.BasicServicesKit';

export enum ReaderCacheKind { Text }

export class ReaderCacheUsage {
  textBytes: number = 0;
}

export class ReaderCacheCleanup {
  releasedBytes: number = 0;
  removed: number = 0;
  protectedCount: number = 0;
  failed: number = 0;
}

class ReaderCacheEntry {
  path: string = '';
  bytes: number = 0;
  usedAt: number = 0;
}

/** Shared by the TypeScript source bridge and ArkTS readers. Only disposable directories are admitted. */
export class ReaderCacheService {
  static readonly TEXT_LIMIT: number = 256 * 1024 * 1024;
  private static context: common.Context | null = null;
  private static entries: Map<string, ReaderCacheEntry> = new Map();
  private static owners: Map<string, Set<string>> = new Map();
  private static holds: Map<string, number> = new Map();
  private static chain: Promise<void> = Promise.resolve();
  private static initialized: boolean = false;
  private static timer: number = -1;
  private static sequence: number = 0;

  static owner(): string { return `reader-cache-${++ReaderCacheService.sequence}`; }

  static configure(context: common.Context): void {
    ReaderCacheService.context = context;
  }

  static reconcile(): void { ReaderCacheService.initialized = false; ReaderCacheService.scheduleTrim(); }

  static async initialize(context: common.Context): Promise<void> {
    ReaderCacheService.configure(context);
    await ReaderCacheService.enqueue(async (): Promise<void> => {
      await ReaderCacheService.ensureIndex();
      await ReaderCacheService.trim(ReaderCacheKind.Text, false);
    });
  }

  static protect(owner: string, paths: string[]): void {
    const safe = new Set<string>();
    for (const raw of paths) {
      const path = ReaderCacheService.localPath(raw);
      if (ReaderCacheService.kind(path) !== undefined) safe.add(path);
    }
    ReaderCacheService.owners.set(owner, safe);
  }

  static release(owner: string): void {
    ReaderCacheService.owners.delete(owner);
    ReaderCacheService.scheduleTrim();
  }

  static hold(raw: string): void {
    const path = ReaderCacheService.localPath(raw);
    if (ReaderCacheService.kind(path) === undefined) return;
    ReaderCacheService.holds.set(path, (ReaderCacheService.holds.get(path) ?? 0) + 1);
  }

  static unhold(raw: string): void {
    const path = ReaderCacheService.localPath(raw);
    const count = ReaderCacheService.holds.get(path) ?? 0;
    if (count <= 1) ReaderCacheService.holds.delete(path);
    else ReaderCacheService.holds.set(path, count - 1);
    ReaderCacheService.scheduleTrim();
  }

  // Upstream image transport may still call these; comic reading budget is removed.
  static beginComicWrite(): void {}
  static endComicWrite(): void {}

  static async record(paths: string[]): Promise<void> {
    await ReaderCacheService.enqueue(async (): Promise<void> => {
      await ReaderCacheService.ensureIndex();
      for (const raw of paths) {
        const path = ReaderCacheService.localPath(raw);
        if (ReaderCacheService.kind(path) === undefined) continue;
        try {
          const stat = await fileIo.stat(path);
          if (!stat.isFile()) continue;
          const entry = new ReaderCacheEntry();
          entry.path = path;
          entry.bytes = stat.size;
          entry.usedAt = Date.now();
          ReaderCacheService.entries.set(path, entry);
          // Persist recency across process restarts; this API takes milliseconds.
          if (entry.usedAt - stat.mtime * 1000 >= 60000) {
            try { fileIo.utimes(path, entry.usedAt); } catch (_error) { /* In-memory recency remains valid. */ }
          }
        } catch (_error) { ReaderCacheService.entries.delete(path); }
      }
    });
    ReaderCacheService.scheduleTrim();
  }

  static forget(path: string): void { ReaderCacheService.entries.delete(path); }

  static async usage(): Promise<ReaderCacheUsage> {
    const usage = new ReaderCacheUsage();
    await ReaderCacheService.enqueue(async (): Promise<void> => {
      await ReaderCacheService.scan();
      for (const entry of ReaderCacheService.entries.values()) {
        if (ReaderCacheService.kind(entry.path) === ReaderCacheKind.Text) usage.textBytes += entry.bytes;
      }
    });
    return usage;
  }

  static async clear(kind: ReaderCacheKind): Promise<ReaderCacheCleanup> {
    let result = new ReaderCacheCleanup();
    await ReaderCacheService.enqueue(async (): Promise<void> => {
      await ReaderCacheService.scan();
      result = await ReaderCacheService.trim(kind, true);
    });
    return result;
  }

  private static enqueue(action: () => Promise<void>): Promise<void> {
    const task = ReaderCacheService.chain.then(action);
    ReaderCacheService.chain = task.catch((): void => {});
    return task;
  }

  private static scheduleTrim(): void {
    if (!ReaderCacheService.context || ReaderCacheService.timer !== -1) return;
    // One deferred sweep for a burst of reads/writes, not one filesystem scan per image.
    ReaderCacheService.timer = setTimeout((): void => {
      ReaderCacheService.timer = -1;
      ReaderCacheService.enqueue(async (): Promise<void> => {
        await ReaderCacheService.ensureIndex();
        await ReaderCacheService.trim(ReaderCacheKind.Text, false);
      }).catch((): void => {});
    }, 1000);
  }

  private static async ensureIndex(): Promise<void> {
    if (!ReaderCacheService.initialized) await ReaderCacheService.scan();
  }

  private static async scan(): Promise<void> {
    const context = ReaderCacheService.context;
    if (!context) return;
    const next = new Map<string, ReaderCacheEntry>();
    const root = `${context.filesDir}/online_text_content`;
    let names: string[];
    try { names = await fileIo.listFile(root); } catch (_error) {
      ReaderCacheService.entries = next;
      ReaderCacheService.initialized = true;
      return;
    }
    for (const name of names) {
      const path = `${root}/${name}`;
      if (ReaderCacheService.kind(path) === undefined) continue;
      try {
        const stat = await fileIo.stat(path);
        if (!stat.isFile()) continue;
        const entry = new ReaderCacheEntry();
        entry.path = path;
        entry.bytes = stat.size;
        entry.usedAt = ReaderCacheService.entries.get(path)?.usedAt ?? stat.mtime * 1000;
        next.set(path, entry);
      } catch (_error) { /* Concurrent cache deletion is a cache miss. */ }
    }
    ReaderCacheService.entries = next;
    ReaderCacheService.initialized = true;
  }

  private static localPath(raw: string): string {
    try { return raw.startsWith('file://') ? new fileUri.FileUri(raw).path : raw; }
    catch (_error) { return ''; }
  }

  private static kind(path: string): ReaderCacheKind | undefined {
    const context = ReaderCacheService.context;
    if (!context || path.includes('..') || path.includes('\\')) return undefined;
    const textRoot = `${context.filesDir}/online_text_content/`;
    if (path.startsWith(textRoot) && /^search_text_[a-z0-9]+\.json$/.test(path.substring(textRoot.length))) return ReaderCacheKind.Text;
    return undefined;
  }

  private static isProtected(path: string, _kind: ReaderCacheKind): boolean {
    if (ReaderCacheService.holds.has(path)) return true;
    for (const paths of ReaderCacheService.owners.values()) if (paths.has(path)) return true;
    return false;
  }

  private static async trim(kind: ReaderCacheKind, clear: boolean): Promise<ReaderCacheCleanup> {
    const result = new ReaderCacheCleanup();
    const entries = Array.from(ReaderCacheService.entries.values()).filter((entry: ReaderCacheEntry): boolean =>
      ReaderCacheService.kind(entry.path) === kind);
    let total = entries.reduce((sum: number, entry: ReaderCacheEntry): number => sum + entry.bytes, 0);
    const limit = ReaderCacheService.TEXT_LIMIT;
    if (!clear && total <= limit) return result;
    const target = clear ? 0 : Math.floor(limit * 0.9);
    entries.sort((left: ReaderCacheEntry, right: ReaderCacheEntry): number => left.usedAt - right.usedAt);
    for (const entry of entries) {
      if (total <= target) break;
      // Re-check at deletion time: readers can acquire a lease while async stat/unlink yields.
      if (ReaderCacheService.isProtected(entry.path, kind)) { result.protectedCount++; continue; }
      try {
        await fileIo.unlink(entry.path);
        total -= entry.bytes;
        result.releasedBytes += entry.bytes;
        result.removed++;
        ReaderCacheService.entries.delete(entry.path);
      } catch (_error) {
        let exists: boolean = true;
        try { exists = await fileIo.access(entry.path); } catch (_accessError) { /* Report unreadable files as failures. */ }
        if (!exists) {
          total -= entry.bytes;
          ReaderCacheService.entries.delete(entry.path);
        } else result.failed++;
      }
    }
    if (result.removed > 0) emitter.emit('app.chapter.cache.updated', { data: {} });
    return result;
  }
}
