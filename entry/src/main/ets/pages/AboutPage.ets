import { common, sendableContextManager } from '@kit.AbilityKit';
import { AppColor, AppFont, AppRadius, AppSpace, AppTheme } from '../theme/Theme';
import { WindowUtils } from '../utils/WindowUtils';
import { UpdateService } from '../service/UpdateService';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { DefaultRuleSourceService } from '../service/rulesource/DefaultRuleSourceService';

const SAMPLE_TAP_TARGET: number = 10;
const SAMPLE_TAP_WINDOW_MS: number = 3000;

@ComponentV2
export struct AboutPage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Local appVersion: string = '0.0.0';
  @Local openingMarket: boolean = false;
  @Local importingSamples: boolean = false;
  private sampleTapCount: number = 0;
  private sampleTapResetAt: number = 0;

  aboutToAppear(): void {
    this.appVersion = UpdateService.getCurrentVersion();
  }

  private async openAppGallery(): Promise<void> {
    if (this.openingMarket) return;
    this.openingMarket = true;
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        throw new Error('UIAbilityContext unavailable');
      }
      const abilityContext = sendableContextManager.convertToUIAbilityContext(
        sendableContextManager.convertFromContext(context));
      await UpdateService.openAppGallery(abilityContext);
    } catch (_e) {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.about_update_open_failed'), duration: 2000
      });
    } finally {
      this.openingMarket = false;
    }
  }

  private onAppIconTap(): void {
    if (this.importingSamples) return;
    const now: number = Date.now();
    if (now > this.sampleTapResetAt) {
      this.sampleTapCount = 0;
    }
    this.sampleTapCount += 1;
    this.sampleTapResetAt = now + SAMPLE_TAP_WINDOW_MS;
    if (this.sampleTapCount < SAMPLE_TAP_TARGET) {
      return;
    }
    this.sampleTapCount = 0;
    this.sampleTapResetAt = 0;
    this.confirmImportSampleRules();
  }

  private confirmImportSampleRules(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: $r('app.string.about_sample_rules_confirm_title'),
      message: $r('app.string.about_sample_rules_confirm_message'),
      buttons: [
        { text: $r('app.string.common_cancel'), color: '#8F8F8F' },
        { text: $r('app.string.about_sample_rules_confirm_action'), color: '#8B6914' }
      ]
    }).then((result): void => {
      if (result.index === 1) {
        this.importSampleRules();
      }
    }).catch((): void => {});
  }

  private async importSampleRules(): Promise<void> {
    if (this.importingSamples) return;
    this.importingSamples = true;
    try {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.about_sample_rules_busy'), duration: 1200
      });
      const host = this.getUIContext().getHostContext();
      if (!host) {
        throw new Error('UIAbilityContext unavailable');
      }
      const context: common.UIAbilityContext = sendableContextManager.convertToUIAbilityContext(
        sendableContextManager.convertFromContext(host));
      const count: number = await DefaultRuleSourceService.importSampleSources(context);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.about_sample_rules_imported', count), duration: 2000
      });
    } catch (_error) {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.about_sample_rules_failed'), duration: 2000
      });
    } finally {
      this.importingSamples = false;
    }
  }

  @Builder
  updateTrailing(): void {
    if (this.openingMarket) {
      LoadingProgress()
        .width(18)
        .height(18)
        .color(AppColor.Brand)
    } else {
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppTheme.TextTertiary])
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemeBackgroundComponent()
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([AppTheme.TextPrimary])
            .onClick(() => this.navStack.pop())
          Text('关于')
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

        Column({ space: AppSpace.Lg }) {
          Column({ space: AppSpace.Sm }) {
            Image($r('app.media.app_icon_legacy'))
              .width(80)
              .height(80)
              .borderRadius(AppRadius.Xl)
              .clip(true)
              .objectFit(ImageFit.Cover)
              .shadow({ radius: 12, color: '#1F000000', offsetY: 4 })
              .onClick((): void => this.onAppIconTap())

            Text($r('app.string.EntryAbility_label'))
              .fontSize(AppFont.TitleL)
              .fontColor(AppTheme.TextPrimary)
              .fontWeight(FontWeight.Bold)
            Text(`v${this.appVersion}`)
              .fontSize(AppFont.Body)
              .fontColor(AppTheme.TextTertiary)
          }
          .alignItems(HorizontalAlign.Center)
          .padding({ top: AppSpace.Xl })

          Column() {
            Row() {
              Text($r('app.string.about_get_update'))
                .fontSize(AppFont.BodyL)
                .fontColor(AppTheme.TextSecondary)
              Blank()
              this.updateTrailing()
            }
            .width('100%')
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg, top: AppSpace.Md, bottom: AppSpace.Md })
            .onClick(() => this.openAppGallery())

            Divider().color(AppTheme.Divider).margin({ left: AppSpace.Lg, right: AppSpace.Lg })

            Row() {
              Text($r('app.string.about_changelog'))
                .fontSize(AppFont.BodyL)
                .fontColor(AppTheme.TextSecondary)
              Blank()
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([AppTheme.TextTertiary])
            }
            .width('100%')
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg, top: AppSpace.Md, bottom: AppSpace.Md })
            .onClick(() => this.navStack.pushPathByName('changelog', ''))

            Divider().color(AppTheme.Divider).margin({ left: AppSpace.Lg, right: AppSpace.Lg })

            Row() {
              Text($r('app.string.about_open_source'))
                .fontSize(AppFont.BodyL)
                .fontColor(AppTheme.TextSecondary)
              Blank()
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([AppTheme.TextTertiary])
            }
            .width('100%')
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg, top: AppSpace.Md, bottom: AppSpace.Md })
            .onClick(() => this.navStack.pushPathByName('openSource', ''))

            Divider().color(AppTheme.Divider).margin({ left: AppSpace.Lg, right: AppSpace.Lg })

            Row() {
              Text($r('app.string.about_compliance_title'))
                .fontSize(AppFont.BodyL)
                .fontColor(AppTheme.TextSecondary)
              Blank()
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([AppTheme.TextTertiary])
            }
            .width('100%')
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg, top: AppSpace.Md, bottom: AppSpace.Md })
            .onClick(() => this.navStack.pushPathByName('compliance', ''))

            Divider().color(AppTheme.Divider).margin({ left: AppSpace.Lg, right: AppSpace.Lg })

            Row() {
              Text('隐私政策')
                .fontSize(AppFont.BodyL)
                .fontColor(AppTheme.TextSecondary)
              Blank()
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([AppTheme.TextTertiary])
            }
            .width('100%')
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg, top: AppSpace.Md, bottom: AppSpace.Md })
            .onClick(() => this.navStack.pushPathByName('privacy', ''))
          }
          .backgroundColor(AppTheme.Surface)
          .borderRadius(AppRadius.Lg)
          .margin({ left: AppSpace.Sm, right: AppSpace.Sm })

          Text($r('app.string.app_description'))
            .fontSize(AppFont.Body)
            .fontColor(AppTheme.TextTertiary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: -(AppSpace.Lg - AppSpace.Md) })

          Text($r('app.string.about_attribution'))
            .fontSize(AppFont.Caption)
            .fontColor(AppTheme.TextTertiary)
            .textAlign(TextAlign.Center)
            .lineHeight(18)
            .width('100%')
            .padding({ left: AppSpace.Lg, right: AppSpace.Lg })
            .margin({ top: AppSpace.Sm })
            .onClick(() => this.navStack.pushPathByName('openSource', ''))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.Background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
