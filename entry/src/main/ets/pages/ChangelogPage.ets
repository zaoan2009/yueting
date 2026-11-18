import { common } from '@kit.AbilityKit';
import { AppFont, AppSpace, AppTheme } from '../theme/Theme';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { WindowUtils } from '../utils/WindowUtils';
import { CharsetCodec } from '../utils/CharsetCodec';

class ChangelogRelease {
  version: string = '';
  items: string[] = [];
}

@ComponentV2
export struct ChangelogPage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Local releases: ChangelogRelease[] = [];
  @Local loadError: string = '';

  aboutToAppear(): void {
    this.loadChangelog();
  }

  private async loadChangelog(): Promise<void> {
    try {
      const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (!host) {
        this.loadError = '无法读取更新日志';
        return;
      }
      const bytes: Uint8Array = await host.resourceManager.getRawFileContent('changelog.json');
      const copy: ArrayBuffer = new ArrayBuffer(bytes.byteLength);
      new Uint8Array(copy).set(bytes);
      const root: Record<string, Object> = JSON.parse(CharsetCodec.decodeBuffer(copy)) as Object as Record<string, Object>;
      const source: Object[] = (root['releases'] as Object[]) ?? [];
      const list: ChangelogRelease[] = [];
      for (let i = 0; i < source.length; i++) {
        const row: Record<string, Object> = source[i] as Record<string, Object>;
        const release = new ChangelogRelease();
        release.version = `${row['version'] ?? ''}`;
        const rawItems: Object[] = (row['items'] as Object[]) ?? [];
        const items: string[] = [];
        for (let j = 0; j < rawItems.length; j++) {
          items.push(`${rawItems[j]}`);
        }
        release.items = items;
        if (release.version.length > 0) {
          list.push(release);
        }
      }
      this.releases = list;
      this.loadError = list.length > 0 ? '' : '暂无更新记录';
    } catch (_error) {
      this.loadError = '更新日志加载失败';
      this.releases = [];
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemeBackgroundComponent()
      Column() {
        this.buildHeader()

        Scroll() {
          Column({ space: AppSpace.Lg }) {
            if (this.loadError.length > 0 && this.releases.length === 0) {
              Text(this.loadError)
                .fontSize(AppFont.Body)
                .fontColor(AppTheme.TextSecondary)
                .width('100%')
                .padding({ left: AppSpace.Lg, right: AppSpace.Lg, top: AppSpace.Xl })
            }

            ForEach(this.releases, (release: ChangelogRelease) => {
              Column({ space: AppSpace.Sm }) {
                Text(`v${release.version}`)
                  .fontSize(AppFont.BodyL)
                  .fontColor(AppTheme.TextPrimary)
                  .fontWeight(FontWeight.Bold)
                  .width('100%')

                ForEach(release.items, (item: string, index: number) => {
                  Text(`· ${item}`)
                    .fontSize(AppFont.Body)
                    .fontColor(AppTheme.TextSecondary)
                    .lineHeight(22)
                    .width('100%')
                }, (item: string, index: number) => `${release.version}-${index}-${item}`)
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: AppSpace.Lg, right: AppSpace.Lg })
            }, (release: ChangelogRelease) => release.version)
          }
          .width('100%')
          .padding({ bottom: WindowUtils.getBottomSafeVp() + AppSpace.Xl })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.Background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildHeader() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([AppTheme.TextPrimary])
        .onClick(() => this.navStack.pop())
      Text($r('app.string.about_changelog'))
        .fontSize(AppFont.Title)
        .fontColor(AppTheme.TextPrimary)
        .fontWeight(FontWeight.Bold)
        .margin({ left: AppSpace.Sm })
    }
    .width('100%')
    .padding({
      top: WindowUtils.getStatusBarHeightVp() + AppSpace.Sm,
      left: AppSpace.Md, right: AppSpace.Md, bottom: AppSpace.Md
    })
  }
}
