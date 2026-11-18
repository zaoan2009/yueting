import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

/** 全局主题背景图：相册选图后复制到 files/theme_bg，不进备份。 */
export class ThemeBackgroundService {
  static readonly DirName: string = 'theme_bg';
  static readonly MaxBytes: number = 12 * 1024 * 1024;

  static dir(context: common.Context): string {
    return `${context.filesDir}/${ThemeBackgroundService.DirName}`;
  }

  static pathOf(context: common.Context, name: string): string {
    return `${ThemeBackgroundService.dir(context)}/${name}`;
  }

  static isSafeName(name: string): boolean {
    return /^bg_[0-9]+\.(jpg|jpeg|png|webp)$/i.test(name);
  }

  static async exists(context: common.Context, name: string): Promise<boolean> {
    if (!ThemeBackgroundService.isSafeName(name)) {
      return false;
    }
    try {
      return await fileIo.access(ThemeBackgroundService.pathOf(context, name));
    } catch (_error) {
      return false;
    }
  }

  static async resolvePath(context: common.Context, name: string): Promise<string> {
    if (name.length === 0) {
      return '';
    }
    if (!await ThemeBackgroundService.exists(context, name)) {
      return '';
    }
    return ThemeBackgroundService.pathOf(context, name);
  }

  /** 选图并落盘，返回新文件名；取消选择返回空串。 */
  static async pickAndSave(context: common.Context): Promise<string> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result = await new photoAccessHelper.PhotoViewPicker().select(options);
    if (result.photoUris.length === 0) {
      return '';
    }
    const dir: string = ThemeBackgroundService.dir(context);
    if (!await fileIo.access(dir)) {
      await fileIo.mkdir(dir, true);
    }
    const name: string = `bg_${Date.now()}.jpg`;
    const destination: string = ThemeBackgroundService.pathOf(context, name);
    const src = await fileIo.open(result.photoUris[0], fileIo.OpenMode.READ_ONLY);
    try {
      await fileIo.copyFile(src.fd, destination);
    } finally {
      await fileIo.close(src);
    }
    try {
      const stat = await fileIo.stat(destination);
      if (stat.size <= 0 || stat.size > ThemeBackgroundService.MaxBytes) {
        await fileIo.unlink(destination);
        throw new Error('Theme background image too large');
      }
      const imageSource = image.createImageSource(destination);
      try {
        await imageSource.getImageInfo();
      } finally {
        await imageSource.release();
      }
    } catch (error) {
      try {
        await fileIo.unlink(destination);
      } catch (_cleanup) {
        // 校验失败时尽量清理半成品。
      }
      throw error instanceof Error ? error : new Error('Theme background decode failed');
    }
    return name;
  }

  static async remove(context: common.Context, name: string): Promise<void> {
    if (!ThemeBackgroundService.isSafeName(name)) {
      return;
    }
    const path: string = ThemeBackgroundService.pathOf(context, name);
    try {
      if (await fileIo.access(path)) {
        await fileIo.unlink(path);
      }
    } catch (_error) {
      // 删除失败不阻断恢复默认。
    }
  }

  /** 清理目录内旧文件，保留 keepName（可空）。 */
  static async prune(context: common.Context, keepName: string = ''): Promise<void> {
    const dir: string = ThemeBackgroundService.dir(context);
    try {
      if (!await fileIo.access(dir)) {
        return;
      }
      const names: string[] = await fileIo.listFile(dir);
      for (let index = 0; index < names.length; index++) {
        const name: string = names[index];
        if (name === keepName || !ThemeBackgroundService.isSafeName(name)) {
          continue;
        }
        try {
          await fileIo.unlink(`${dir}/${name}`);
        } catch (_error) {
          // 个别文件清理失败不影响当前背景。
        }
      }
    } catch (_error) {
      // 目录不可用时忽略。
    }
  }
}
