import { bundleManager } from '@kit.AbilityKit';
import { PlatformCompat } from '../utils/PlatformCompat';

/** API 26+ 按播放态切换桌面备用图标；未播放用默认闭眼微笑猫，播放用厌世猫。 */
export class AppIconService {
  private static readonly shared: AppIconService = new AppIconService();
  /** 与 AppScope/app.json5 alternateIcons.name 一致。 */
  static readonly PLAYING_ICON: string = 'playing';

  private changing: boolean = false;
  private desiredPlaying: boolean = false;
  private appliedName: string | null = null;
  private queued: boolean = false;

  static get instance(): AppIconService {
    return AppIconService.shared;
  }

  get supported(): boolean {
    return PlatformCompat.supports(26);
  }

  /** 启动或恢复后按当前是否在播同步桌面图标。 */
  async syncPlaybackIcon(playing: boolean): Promise<void> {
    this.desiredPlaying = playing;
    if (!this.supported) {
      return;
    }
    if (this.changing) {
      this.queued = true;
      return;
    }
    const target: string = playing ? AppIconService.PLAYING_ICON : '';
    if (this.appliedName === target) {
      return;
    }
    this.changing = true;
    try {
      await bundleManager.setAlternateIcon(target);
      this.appliedName = target;
    } catch (_error) {
      // 图标切换失败不影响播放；下次状态变化再试。
      this.appliedName = null;
    } finally {
      this.changing = false;
      if (this.queued) {
        this.queued = false;
        const again: boolean = this.desiredPlaying;
        await this.syncPlaybackIcon(again);
      }
    }
  }
}
