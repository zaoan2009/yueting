import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileShare, fileUri, picker } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlatformCompat } from '../utils/PlatformCompat';

const DOMAIN: number = 0x0001;
const TAG: string = 'DownloadLocation';
const STORE_NAME: string = 'download_location_v1';
const KEY_MODE: string = 'mode';
const KEY_ROOT_URI: string = 'root_uri';
const AUDIO_DIR: string = 'audio';

/** sandbox=应用内；public_download=系统 Download/包名；custom=用户自选文件夹 */
export type DownloadLocationMode = 'sandbox' | 'public_download' | 'custom';

export class DownloadLocationSnapshot {
  mode: DownloadLocationMode = 'sandbox';
  rootUri: string = '';
  ready: boolean = true;
  displayName: string = '';
  supportsCustomFolder: boolean = false;
  supportsPublicDownload: boolean = false;
}

/**
 * 正式离线下载音频根目录：默认系统 Download/包名；手表强制沙箱；
 * API 26+ 且具备 FolderSelection 时可自选文件夹并持久授权。
 * 索引 JSON 仍固定在沙箱，仅音频文件跟随本服务。
 */
export class DownloadLocationService {
  private static instance: DownloadLocationService | null = null;
  private context: common.UIAbilityContext | null = null;
  private store: preferences.Preferences | null = null;
  private mode: DownloadLocationMode = 'sandbox';
  private rootUri: string = '';
  private ready: boolean = true;
  private initPromise: Promise<void> | null = null;

  static getInstance(): DownloadLocationService {
    if (DownloadLocationService.instance === null) {
      DownloadLocationService.instance = new DownloadLocationService();
    }
    return DownloadLocationService.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.initPromise === null) {
      this.initPromise = this.loadAndPrepare();
    }
    await this.initPromise;
  }

  snapshot(): DownloadLocationSnapshot {
    const snap: DownloadLocationSnapshot = new DownloadLocationSnapshot();
    snap.mode = this.mode;
    snap.rootUri = this.rootUri;
    snap.ready = this.ready;
    snap.displayName = this.displayName();
    snap.supportsCustomFolder = DownloadLocationService.canSelectCustomFolder();
    snap.supportsPublicDownload = DownloadLocationService.canUsePublicDownload();
    return snap;
  }

  /** 当前音频根目录的可 fileIo 路径；沙箱为 filesDir/downloads/audio。 */
  getAudioRootPath(): string | null {
    if (!this.context) return null;
    if (this.mode === 'sandbox' || this.rootUri.length === 0 || !this.ready) {
      return `${this.context.filesDir}/downloads/${AUDIO_DIR}`;
    }
    return DownloadLocationService.uriToPath(this.rootUri, AUDIO_DIR);
  }

  /** 外置根 URI（不含 audio 子目录）；沙箱为空。 */
  getRootUri(): string {
    return this.mode === 'sandbox' ? '' : this.rootUri;
  }

  isUsingExternal(): boolean {
    return this.mode !== 'sandbox' && this.rootUri.length > 0 && this.ready;
  }

  static canUsePublicDownload(): boolean {
    return !PlatformCompat.wearable;
  }

  static canSelectCustomFolder(): boolean {
    if (PlatformCompat.wearable) return false;
    if (!PlatformCompat.supports(26)) return false;
    try {
      return canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection');
    } catch (_error) {
      return false;
    }
  }

  async useSandbox(): Promise<void> {
    this.mode = 'sandbox';
    this.rootUri = '';
    this.ready = true;
    await this.persist();
  }

  async usePublicDownload(): Promise<void> {
    if (!DownloadLocationService.canUsePublicDownload() || !this.context) {
      throw new Error('当前设备不支持系统下载目录');
    }
    const uri: string = await this.acquirePublicDownloadUri();
    this.mode = 'public_download';
    this.rootUri = uri;
    this.ready = true;
    await this.ensureAudioDir();
    await this.persist();
  }

  async useCustomFolder(): Promise<void> {
    if (!DownloadLocationService.canSelectCustomFolder() || !this.context) {
      throw new Error('当前系统不支持自选下载文件夹');
    }
    const uri: string = await this.selectAndPersistFolder();
    this.mode = 'custom';
    this.rootUri = uri;
    this.ready = true;
    await this.activateRootPermission();
    await this.ensureAudioDir();
    await this.persist();
  }

  /** 冷启动后激活自选目录持久权限；DOWNLOAD 模式通常无需 activate。 */
  async activateIfNeeded(): Promise<void> {
    if (this.mode !== 'custom' || this.rootUri.length === 0) return;
    try {
      await this.activateRootPermission();
      this.ready = true;
      await this.ensureAudioDir();
    } catch (error) {
      this.ready = false;
      hilog.warn(DOMAIN, TAG, 'activate custom folder failed: %{public}s',
        error instanceof Error ? error.message : String(error));
    }
  }

  /** 清理用：返回需要扫删的音频根路径（含沙箱与当前外置）。 */
  listCleanupAudioRoots(): string[] {
    const roots: string[] = [];
    if (this.context) {
      roots.push(`${this.context.filesDir}/downloads/${AUDIO_DIR}`);
    }
    if (this.rootUri.length > 0) {
      const external: string | null = DownloadLocationService.uriToPath(this.rootUri, AUDIO_DIR);
      if (external && roots.indexOf(external) < 0) roots.push(external);
    }
    return roots;
  }

  private async loadAndPrepare(): Promise<void> {
    if (!this.context) return;
    if (PlatformCompat.wearable) {
      this.mode = 'sandbox';
      this.rootUri = '';
      this.ready = true;
      return;
    }
    this.store = await preferences.getPreferences(this.context, { name: STORE_NAME });
    const savedMode: string = String(await this.store.get(KEY_MODE, '') ?? '');
    const savedUri: string = String(await this.store.get(KEY_ROOT_URI, '') ?? '');
    if (savedMode === 'sandbox' || savedMode === 'public_download' || savedMode === 'custom') {
      this.mode = savedMode;
      this.rootUri = savedUri;
    } else {
      // 新安装默认系统下载目录；获取失败则运行时用沙箱。
      this.mode = 'public_download';
      this.rootUri = '';
    }
    if (this.mode === 'sandbox') {
      this.ready = true;
      return;
    }
    if (this.mode === 'public_download') {
      try {
        if (this.rootUri.length === 0) {
          this.rootUri = await this.acquirePublicDownloadUri();
          await this.persist();
        }
        await this.ensureAudioDir();
        this.ready = true;
      } catch (error) {
        this.ready = false;
        hilog.warn(DOMAIN, TAG, 'public download root unavailable: %{public}s',
          error instanceof Error ? error.message : String(error));
      }
      return;
    }
    await this.activateIfNeeded();
  }

  private async acquirePublicDownloadUri(): Promise<string> {
    if (!this.context) throw new Error('下载位置未初始化');
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
    const uris: Array<string> = await new picker.DocumentViewPicker(this.context).save(options);
    if (!uris || uris.length === 0 || uris[0].length === 0) {
      throw new Error('未获得系统下载目录');
    }
    return uris[0];
  }

  private async selectAndPersistFolder(): Promise<string> {
    if (!this.context) throw new Error('下载位置未初始化');
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.selectMode = picker.DocumentSelectMode.FOLDER;
    options.maxSelectNumber = 1;
    const uris: Array<string> = await new picker.DocumentViewPicker(this.context).select(options);
    if (!uris || uris.length === 0 || uris[0].length === 0) {
      throw new Error('未选择文件夹');
    }
    const uri: string = uris[0];
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE
    };
    const policies: Array<fileShare.PolicyInfo> = [policy];
    await fileShare.persistPermission(policies);
    return uri;
  }

  private async activateRootPermission(): Promise<void> {
    if (this.rootUri.length === 0) return;
    const policy: fileShare.PolicyInfo = {
      uri: this.rootUri,
      operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE
    };
    const policies: Array<fileShare.PolicyInfo> = [policy];
    await fileShare.activatePermission(policies);
  }

  private async ensureAudioDir(): Promise<void> {
    const path: string | null = this.getAudioRootPath();
    if (!path) return;
    try {
      const exists: boolean = await fileIo.access(path);
      if (exists) return;
    } catch (_error) {
      // mkdir below
    }
    try {
      await fileIo.mkdir(path);
    } catch (error) {
      const code: number = (error as BusinessError).code ?? 0;
      // 已存在
      if (code !== 13900015) {
        throw error instanceof Error ? error : new Error(String(error));
      }
    }
  }

  private async persist(): Promise<void> {
    if (!this.store) {
      if (!this.context) return;
      this.store = await preferences.getPreferences(this.context, { name: STORE_NAME });
    }
    await this.store.put(KEY_MODE, this.mode);
    await this.store.put(KEY_ROOT_URI, this.rootUri);
    await this.store.flush();
  }

  private displayName(): string {
    if (this.mode === 'sandbox' || !this.ready) {
      return this.mode === 'sandbox' ? '应用内存储' : '外置目录暂不可用，已回退应用内';
    }
    if (this.mode === 'public_download') {
      return '系统下载目录（Download/悦听）';
    }
    if (this.rootUri.length === 0) return '自选文件夹';
    const parts: string[] = this.rootUri.split('/');
    const name: string = parts.length > 0 ? parts[parts.length - 1] : '';
    return name.length > 0 ? `自选文件夹 · ${name}` : '自选文件夹';
  }

  private static uriToPath(rootUri: string, ...segments: string[]): string | null {
    try {
      let uri: string = rootUri.endsWith('/') ? rootUri.substring(0, rootUri.length - 1) : rootUri;
      for (let index = 0; index < segments.length; index++) {
        const segment: string = segments[index];
        if (segment.length === 0) continue;
        uri = `${uri}/${segment}`;
      }
      return new fileUri.FileUri(uri).path;
    } catch (_error) {
      return null;
    }
  }
}
