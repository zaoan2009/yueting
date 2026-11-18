import { common } from '@kit.AbilityKit';
import { AppAppearance } from '../model/AppAppearance';
import { PreferenceService } from '../service/PreferenceService';
import { ThemeBackgroundService } from '../service/ThemeBackgroundService';
import { AppColor, AppFont, AppRadius, AppSpace, AppTheme } from '../theme/Theme';
import { ThemeBundles } from '../theme/ThemeBundles';
import { CoverImage } from './CoverImage';
import { ImmersiveActionButton } from './ImmersiveActionButton';

class ThemeColorSwatch {
  color: string;
  label: Resource;
  constructor(color: string, label: Resource) {
    this.color = color;
    this.label = label;
  }
}

const ACCENT_SWATCHES: ThemeColorSwatch[] = [
  new ThemeColorSwatch(ThemeBundles.GinkgoAccent, $r('app.string.theme_custom_swatch_ginkgo')),
  new ThemeColorSwatch('#FF6B3D', $r('app.string.appearance_accent_orange')),
  new ThemeColorSwatch('#C4475B', $r('app.string.appearance_accent_rose')),
  new ThemeColorSwatch('#8E55B8', $r('app.string.appearance_accent_purple')),
  new ThemeColorSwatch('#2869B8', $r('app.string.appearance_accent_blue')),
  new ThemeColorSwatch('#008577', $r('app.string.appearance_accent_teal')),
  new ThemeColorSwatch('#557C36', $r('app.string.appearance_accent_green'))
];

const SURFACE_SWATCHES: ThemeColorSwatch[] = [
  new ThemeColorSwatch(ThemeBundles.GinkgoSurface, $r('app.string.theme_custom_swatch_ginkgo')),
  new ThemeColorSwatch('#FFFFFF', $r('app.string.theme_custom_swatch_white')),
  new ThemeColorSwatch('#F5F5F5', $r('app.string.theme_custom_swatch_gray')),
  new ThemeColorSwatch('#FFF8F0', $r('app.string.theme_custom_swatch_warm')),
  new ThemeColorSwatch('#F0F4FF', $r('app.string.theme_custom_swatch_cool'))
];

const BACKGROUND_SWATCHES: ThemeColorSwatch[] = [
  new ThemeColorSwatch(ThemeBundles.GinkgoBackground, $r('app.string.theme_custom_swatch_ginkgo')),
  new ThemeColorSwatch('#F7F7F7', $r('app.string.theme_custom_swatch_gray')),
  new ThemeColorSwatch('#FFF8F0', $r('app.string.theme_custom_swatch_warm')),
  new ThemeColorSwatch('#EEF3FF', $r('app.string.theme_custom_swatch_cool')),
  new ThemeColorSwatch('#1C1C1E', $r('app.string.theme_custom_swatch_dark'))
];

const TEXT_SWATCHES: ThemeColorSwatch[] = [
  new ThemeColorSwatch(ThemeBundles.GinkgoText, $r('app.string.theme_custom_swatch_ginkgo')),
  new ThemeColorSwatch('#191919', $r('app.string.theme_custom_swatch_dark')),
  new ThemeColorSwatch('#333333', $r('app.string.theme_custom_swatch_gray')),
  new ThemeColorSwatch('#FFFFFF', $r('app.string.theme_custom_swatch_white'))
];

/** 主题页：银杏默认 + 全局自定义背景图与色板。 */
@ComponentV2
export struct ThemeBundleComponent {
  @Local appearance: AppAppearance = AppAppearance.current;
  @Local saving: boolean = false;
  @Local pickingBackground: boolean = false;
  @Local draftBackground: string = ThemeBundles.GinkgoBackground;
  @Local draftSurface: string = ThemeBundles.GinkgoSurface;
  @Local draftText: string = ThemeBundles.GinkgoText;
  @Local draftAccent: string = ThemeBundles.GinkgoAccent;
  @Local hexField: string = '';
  @Local hexTarget: string = 'accent';
  @Local hexInvalid: boolean = false;

  aboutToAppear(): void {
    this.syncDraftFromAppearance();
  }

  private syncDraftFromAppearance(): void {
    this.draftBackground = this.appearance.backgroundColor.length > 0 ?
      this.appearance.backgroundColor : ThemeBundles.GinkgoBackground;
    this.draftSurface = this.appearance.surfaceColor.length > 0 ?
      this.appearance.surfaceColor : ThemeBundles.GinkgoSurface;
    this.draftText = this.appearance.textColor.length > 0 ?
      this.appearance.textColor : ThemeBundles.GinkgoText;
    this.draftAccent = this.appearance.accent.length > 0 ?
      this.appearance.accent : ThemeBundles.GinkgoAccent;
  }

  private isCustomized(): boolean {
    return AppAppearance.hasCustomPalette() ||
      this.appearance.accent !== ThemeBundles.GinkgoAccent ||
      this.appearance.material !== 3;
  }

  private showResult(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // 页面离开后无需提示。
    }
  }

  private async restoreDefault(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      await PreferenceService.restoreDefaultTheme();
      this.syncDraftFromAppearance();
      this.showResult($r('app.string.theme_bundle_changed'));
    } catch (_error) {
      this.showResult($r('app.string.theme_bundle_failed'));
    } finally {
      this.saving = false;
    }
  }

  private async savePalette(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const background: string = this.draftBackground === ThemeBundles.GinkgoBackground ? '' : this.draftBackground;
      const surface: string = this.draftSurface === ThemeBundles.GinkgoSurface ? '' : this.draftSurface;
      const text: string = this.draftText === ThemeBundles.GinkgoText ? '' : this.draftText;
      await PreferenceService.setThemePalette(background, surface, text, this.draftAccent);
      this.syncDraftFromAppearance();
      this.showResult($r('app.string.theme_custom_saved'));
    } catch (_error) {
      this.showResult($r('app.string.theme_bundle_failed'));
    } finally {
      this.saving = false;
    }
  }

  private async pickBackground(): Promise<void> {
    if (this.saving || this.pickingBackground) {
      return;
    }
    const host = this.getUIContext().getHostContext();
    if (host === null || host === undefined) {
      return;
    }
    const context: common.Context = host as common.Context;
    this.pickingBackground = true;
    try {
      const name: string = await ThemeBackgroundService.pickAndSave(context);
      if (name.length === 0) {
        return;
      }
      await PreferenceService.setCustomBackgroundName(name);
      this.showResult($r('app.string.theme_custom_bg_changed'));
    } catch (_error) {
      this.showResult($r('app.string.theme_custom_bg_failed'));
    } finally {
      this.pickingBackground = false;
    }
  }

  private async clearBackground(): Promise<void> {
    if (this.saving || this.pickingBackground || this.appearance.customBackgroundName.length === 0) {
      return;
    }
    this.pickingBackground = true;
    try {
      await PreferenceService.setCustomBackgroundName('');
      this.showResult($r('app.string.theme_custom_bg_cleared'));
    } catch (_error) {
      this.showResult($r('app.string.theme_bundle_failed'));
    } finally {
      this.pickingBackground = false;
    }
  }

  private applyHex(): void {
    const normalized: string = AppAppearance.normalizeAccent(this.hexField);
    this.hexInvalid = normalized.length === 0;
    if (this.hexInvalid) {
      return;
    }
    if (this.hexTarget === 'background') {
      this.draftBackground = normalized;
    } else if (this.hexTarget === 'surface') {
      this.draftSurface = normalized;
    } else if (this.hexTarget === 'text') {
      this.draftText = normalized;
    } else {
      this.draftAccent = normalized;
    }
  }

  @Builder
  private swatchRow(title: Resource, value: string, swatches: ThemeColorSwatch[], target: string) {
    Column({ space: AppSpace.Xs }) {
      Row() {
        Text(title).fontSize(AppFont.Body).fontWeight(FontWeight.Medium).fontColor(AppTheme.TextPrimary)
          .layoutWeight(1)
        Row().width(18).height(18).borderRadius(9).backgroundColor(value)
          .border({ width: 1, color: AppTheme.Divider })
        Text(value).fontSize(AppFont.Caption).fontColor(AppTheme.TextSecondary).margin({ left: 6 })
      }.width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(swatches, (swatch: ThemeColorSwatch) => {
          Column({ space: 4 }) {
            Stack() {
              Row().width(36).height(36).borderRadius(18).backgroundColor(swatch.color)
                .border({ width: value === swatch.color ? 2 : 1,
                  color: value === swatch.color ? AppColor.Brand : AppTheme.Divider })
              if (value === swatch.color) {
                SymbolGlyph($r('sys.symbol.checkmark')).fontSize(16)
                  .fontColor([AppAppearance.foreground(swatch.color)])
              }
            }
          }
          .width('20%')
          .padding({ top: 6, bottom: 6 })
          .onClick(() => {
            if (target === 'background') {
              this.draftBackground = swatch.color;
            } else if (target === 'surface') {
              this.draftSurface = swatch.color;
            } else if (target === 'text') {
              this.draftText = swatch.color;
            } else {
              this.draftAccent = swatch.color;
            }
            this.hexTarget = target;
            this.hexField = swatch.color;
            this.hexInvalid = false;
          })
        }, (swatch: ThemeColorSwatch) => `${target}-${swatch.color}`)
      }
      .width('100%')
    }.width('100%')
  }

  @Builder
  private previewCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.appearance.customBackgroundPath.length > 0) {
        Image(this.appearance.customBackgroundPath)
          .width('100%').height('100%').objectFit(ImageFit.Cover)
          .position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
      } else {
        Image(ThemeBundles.backgroundImage())
          .width('100%').height('100%').objectFit(ImageFit.Cover)
          .position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
      }
      Column({ space: 8 }) {
        Text($r('app.string.theme_bundle_preview_label'))
          .fontSize(10).fontColor(this.draftText)
        Row({ space: 8 }) {
          CoverImage({
            title: '预览',
            imgWidth: 40,
            imgHeight: 56,
            useFixedHeight: true,
            radius: 3,
            themeBundleId: ThemeBundles.GinkgoId
          })
          Column({ space: 4 }) {
            Text($r('app.string.theme_bundle_ginkgo_name'))
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.draftText)
            Text($r('app.string.theme_bundle_ginkgo_description'))
              .fontSize(10).fontColor(AppAppearance.withAlpha(this.draftText, '99')).maxLines(2)
            Row().width(64).height(8).borderRadius(4).backgroundColor(this.draftAccent).margin({ top: 4 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').padding(10).borderRadius(10).backgroundColor(this.draftSurface)
      }.width('100%').padding(12)
    }.width('100%').height(168).borderRadius(AppRadius.Md).clip(true)
    .backgroundColor(this.draftBackground)
    .border({ width: 1, color: AppTheme.Divider })
  }

  build() {
    Column({ space: AppSpace.Section }) {
      Text($r('app.string.theme_bundle_hint')).fontSize(AppFont.Caption).lineHeight(20)
        .fontColor(AppTheme.TextSecondary).width('100%')

      Column({ space: AppSpace.Sm }) {
        Row({ space: AppSpace.Xs }) {
          Text($r('app.string.theme_bundle_ginkgo_name')).fontSize(AppFont.BodyL).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TextPrimary).layoutWeight(1)
          if (!this.isCustomized()) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(14).fontColor([AppColor.Brand])
              Text($r('app.string.theme_bundle_applied')).fontSize(AppFont.Caption).fontColor(AppColor.Brand)
            }
          }
        }.width('100%')
        Text($r('app.string.theme_bundle_ginkgo_description')).fontSize(AppFont.Caption)
          .fontColor(AppTheme.TextSecondary).lineHeight(18).width('100%')
        this.previewCard()
        if (this.isCustomized()) {
          Button($r('app.string.theme_bundle_restore'))
            .fontSize(AppFont.Body).fontColor(AppTheme.TextSecondary).backgroundColor(Color.Transparent)
            .enabled(!this.saving && !this.pickingBackground)
            .onClick(() => this.restoreDefault())
        }
      }.width('100%').padding(AppSpace.Md).borderRadius(AppRadius.Lg)
      .backgroundColor(AppTheme.Surface)
      .border({ width: 1, color: AppTheme.Divider })

      Column({ space: AppSpace.Md }) {
        Text($r('app.string.theme_custom_title')).fontSize(AppFont.BodyL).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TextPrimary).width('100%')
        Text($r('app.string.theme_custom_hint')).fontSize(AppFont.Caption).lineHeight(18)
          .fontColor(AppTheme.TextSecondary).width('100%')

        Column({ space: AppSpace.Sm }) {
          Text($r('app.string.theme_custom_background_image')).fontSize(AppFont.Body)
            .fontWeight(FontWeight.Medium).fontColor(AppTheme.TextPrimary).width('100%')
          Row({ space: AppSpace.Sm }) {
            Stack() {
              if (this.appearance.customBackgroundPath.length > 0) {
                Image(this.appearance.customBackgroundPath)
                  .width('100%').height('100%').objectFit(ImageFit.Cover).borderRadius(AppRadius.Sm)
              } else {
                Image(ThemeBundles.backgroundImage())
                  .width('100%').height('100%').objectFit(ImageFit.Cover).borderRadius(AppRadius.Sm)
              }
            }.width(72).height(96).borderRadius(AppRadius.Sm).clip(true)
            .border({ width: 1, color: AppTheme.Divider })
            Column({ space: AppSpace.Xs }) {
              ImmersiveActionButton({
                label: this.pickingBackground ? $r('app.string.theme_custom_bg_picking') :
                  $r('app.string.theme_custom_bg_pick'),
                textSize: AppFont.Body,
                onPress: (): void => {
                  this.pickBackground();
                }
              }).width('100%').enabled(!this.saving && !this.pickingBackground)
              if (this.appearance.customBackgroundName.length > 0) {
                Button($r('app.string.theme_custom_bg_clear'))
                  .fontSize(AppFont.Body).fontColor(AppTheme.TextSecondary)
                  .backgroundColor(Color.Transparent)
                  .enabled(!this.saving && !this.pickingBackground)
                  .onClick(() => this.clearBackground())
              }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
        }.width('100%')

        this.swatchRow($r('app.string.theme_custom_background_color'), this.draftBackground,
          BACKGROUND_SWATCHES, 'background')
        this.swatchRow($r('app.string.theme_custom_surface_color'), this.draftSurface,
          SURFACE_SWATCHES, 'surface')
        this.swatchRow($r('app.string.theme_custom_text_color'), this.draftText, TEXT_SWATCHES, 'text')
        this.swatchRow($r('app.string.theme_custom_accent_color'), this.draftAccent, ACCENT_SWATCHES, 'accent')

        Column({ space: AppSpace.Xs }) {
          Text($r('app.string.theme_custom_hex_title')).fontSize(AppFont.Caption)
            .fontColor(AppTheme.TextSecondary).width('100%')
          Row({ space: AppSpace.Sm }) {
            TextInput({ text: this.hexField, placeholder: $r('app.string.appearance_accent_hex_hint') })
              .layoutWeight(1).maxLength(7)
              .onChange((value: string) => {
                this.hexField = value;
                this.hexInvalid = false;
              })
              .onSubmit(() => this.applyHex())
            ImmersiveActionButton({
              label: $r('app.string.theme_custom_hex_apply'),
              textSize: AppFont.Body,
              onPress: (): void => this.applyHex()
            }).width(72)
          }.width('100%')
          if (this.hexInvalid) {
            Text($r('app.string.appearance_accent_invalid')).fontSize(AppFont.Caption)
              .fontColor(AppTheme.TextPrimary).width('100%')
          }
          Text($r('app.string.theme_custom_hex_target_hint')).fontSize(AppFont.Caption)
            .fontColor(AppTheme.TextTertiary).width('100%')
        }.width('100%')

        Button({ type: ButtonType.Normal }) {
          Row({ space: AppSpace.Xs }) {
            if (this.saving) {
              LoadingProgress().width(18).height(18).color(AppColor.OnBrand)
            }
            Text(this.saving ? $r('app.string.theme_bundle_applying') : $r('app.string.theme_custom_apply'))
              .fontSize(AppFont.Body).fontWeight(FontWeight.Medium).fontColor(AppColor.OnBrand)
          }.justifyContent(FlexAlign.Center)
        }.width('100%').height(44).borderRadius(AppRadius.Sm)
        .backgroundColor(AppColor.Brand)
        .enabled(!this.saving && !this.pickingBackground)
        .onClick(() => this.savePalette())
      }.width('100%').padding(AppSpace.Md).borderRadius(AppRadius.Lg)
      .backgroundColor(AppTheme.Surface)
      .border({ width: 1, color: AppTheme.Divider })
    }.width('100%')
  }
}
