import { MedalService } from '../service/MedalService';
import { HdsCompat } from '../utils/HdsCompat';
import { AppColor, AppRadius, AppSpace, AppFont, AppTheme } from '../theme/Theme';
import { ThemeBackgroundComponent } from '../components/ThemeBackgroundComponent';
import { ThemeIconComponent } from '../components/ThemeIconComponent';
import { ThemeIconRole } from '../theme/ThemeIcons';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { WindowUtils } from '../utils/WindowUtils';
import { AuthService } from '../service/AuthService';
import { AccountAvatar } from '../components/AccountAvatar';
class ProfileItem {
  icon: Resource;
  themeRole: ThemeIconRole;
  label: ResourceStr;
  id: string;
  private iconBackground: ResourceColor;
  /** 副标题；空时不占位 */
  subtitle: ResourceStr;

  constructor(icon: Resource, themeRole: ThemeIconRole, label: ResourceStr, id: string,
    iconBg: ResourceColor, subtitle: ResourceStr = '') {
    this.icon = icon;
    this.themeRole = themeRole;
    this.label = label;
    this.id = id;
    this.iconBackground = iconBg;
    this.subtitle = subtitle;
  }

  get iconBg(): ResourceColor {
    if (AppTheme.hasSkin || this.id === 'ruleSources' || this.id === 'theme') {
      return AppColor.Brand;
    }
    return this.iconBackground;
  }
}

const SOURCE_ITEMS: ProfileItem[] = [
  new ProfileItem($r('sys.symbol.bookshelf'), ThemeIconRole.RuleSource, $r('app.string.rule_source_title'),
    'ruleSources', $r('app.color.app_brand')),
  new ProfileItem($r('sys.symbol.arrow_down_circle'), ThemeIconRole.Downloads, $r('app.string.download_open_manager'),
    'downloads', '#007AFF')
];

const CONTENT_ITEMS: ProfileItem[] = [
  new ProfileItem($r('sys.symbol.star_fill'), ThemeIconRole.Achievements, $r('app.string.achievement_title'),
    'achievements', '#E6A23C'),
  new ProfileItem($r('sys.symbol.star_fill'), ThemeIconRole.Theme, $r('app.string.theme_page_title'),
    'theme', $r('app.color.app_brand'))
];

const SETTINGS_ITEMS: ProfileItem[] = [
  new ProfileItem($r('sys.symbol.gearshape'), ThemeIconRole.Settings, '设置', 'settings', '#8E8E93')
];

const SYSTEM_ITEMS: ProfileItem[] = [
  new ProfileItem($r('sys.symbol.info_circle'), ThemeIconRole.About, '关于', 'about', '#0A59F7')
];

const ROW_INDENT: number = AppSpace.Md;
const MINI_TITLE_BAR_HEIGHT: number = 56;

@ComponentV2
export struct ProfilePage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Event onScrollerReady: (scroller: Scroller) => void = () => {};
  @Local medalService: MedalService = MedalService.instance;
  @Local auth: AuthService = AuthService.instance;

  private scrollScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.onScrollerReady(this.scrollScroller);
    const context = this.getUIContext().getHostContext();
    if (context) {
      this.auth.restore(context);
      this.medalService.init(context).catch((error: Error): void => {
        console.warn(`[ProfilePage] medals unavailable: ${error.message}`);
      });
    }
  }

  private onItemTap(id: string): void {
    if (id === 'downloads') {
      this.navStack.pushPathByName('downloads', null);
    } else if (id === 'achievements') {
      this.navStack.pushPathByName('achievements', '');
    } else if (id === 'account') {
      this.navStack.pushPathByName('account', '');
    } else if (id === 'settings') {
      this.navStack.pushPathByName('settings', '');

    } else if (id === 'theme') {
      this.navStack.pushPathByName('theme', '');
    } else if (id === 'ruleSources') {
      this.navStack.pushPathByName('ruleSources', '');
    } else if (id === 'about') {
      this.navStack.pushPathByName('about', '');
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ThemeBackgroundComponent()

      HdsNavigation() {
        Scroll(this.scrollScroller) {
          Column({ space: AppSpace.Section }) {
            this.buildAccountCard()
            this.buildGroup(SOURCE_ITEMS)
            this.buildGroup(SETTINGS_ITEMS)
            this.buildGroup(CONTENT_ITEMS)
            this.buildGroup(SYSTEM_ITEMS)
          }
          .width('100%')
          .padding({
            left: AppSpace.PageX,
            right: AppSpace.PageX,
            top: WindowUtils.getStatusBarHeightVp() + MINI_TITLE_BAR_HEIGHT + AppSpace.Md,
            bottom: WindowUtils.getFloatingTabBottomVp()
          })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .backgroundColor(Color.Transparent)
        .align(Alignment.Top)
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: {
            mainTitle: '我的'
          }
        },
        style: {
          scrollEffectOpts: {
            scrollEffectType: HdsCompat.scrollEffect
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: Color.Transparent
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: AppTheme.TextPrimary
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: Color.Transparent
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: AppTheme.TextPrimary
              }
            }
          },
          systemMaterialEffect: HdsCompat.material
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .bindToScrollable([this.scrollScroller])
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildAccountCard() {
    Column() {
      Row({ space: AppSpace.Sm }) {
        AccountAvatar({ uri: this.auth.avatarUri, avatarSize: 44 })
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(this.auth.isLoggedIn ? (this.auth.nickName || $r('app.string.hw_auth_account_title')) :
              $r('app.string.hw_auth_login_title'))
              .fontSize(AppFont.BodyL)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TextPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .flexShrink(1)
          }.width('100%').alignItems(VerticalAlign.Center)
          if (this.auth.isLoggedIn && this.medalService.ready && this.medalService.accountId === this.auth.openID) {
            Row({ space: 4 }) {
              Text($r('app.string.profile_usage_level', this.medalService.usageLevel()))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#B88935')
                .maxLines(1)
                .flexShrink(0)
              Text(this.medalService.usageLevelName())
                .fontSize(12)
                .fontColor('#B88935')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .flexShrink(1)
            }.alignItems(VerticalAlign.Center).constraintSize({ maxWidth: '100%' })
          }
          if (!this.auth.isLoggedIn) {
            Text($r('app.string.hw_auth_login_desc'))
              .fontSize(AppFont.Caption)
              .fontColor(AppTheme.TextTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .constraintSize({ minHeight: 44 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)

        if (this.auth.logging || this.auth.restoring) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(AppColor.Brand)
            .accessibilityText($r('app.string.hw_auth_processing'))
        } else {
          ThemeIconComponent({ role: ThemeIconRole.ChevronRight, symbol: $r('sys.symbol.chevron_right'),
            iconSize: 24, tint: AppTheme.TextTertiary })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({
        left: ROW_INDENT,
        right: ROW_INDENT,
        top: AppSpace.Sm,
        bottom: AppSpace.Sm
      })
      .constraintSize({ minHeight: 56 })
      .enabled(!this.auth.logging && !this.auth.restoring)
      .onClick(() => {
        this.navStack.pushPathByName('account', '');
      })
    }.width('100%').backgroundColor(AppTheme.Surface).borderRadius(AppRadius.Lg)
  }

  @Builder
  buildGroup(items: ProfileItem[], title: string = '') {
    Column() {
      if (title.length > 0) {
        Text(title)
          .fontSize(AppFont.Body)
          .fontColor(AppTheme.TextTertiary)
          .padding({ left: AppSpace.Sm, bottom: AppSpace.Xs })
      }

      Column() {
        ForEach(items, (item: ProfileItem, index: number) => {
          this.buildRow(item)
          if (index < items.length - 1) {
            Divider()
              .strokeWidth(0.5)
              .color(AppTheme.Divider)
              .margin({ left: ROW_INDENT + 28 + AppSpace.Sm })
          }
        }, (item: ProfileItem) => item.id)
      }
      .width('100%')
      .backgroundColor(AppTheme.Surface)
      .borderRadius(AppRadius.Lg)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildRow(item: ProfileItem) {
    Row({ space: AppSpace.Sm }) {
      Stack() {
        ThemeIconComponent({
          role: item.themeRole,
          symbol: item.icon,
          iconSize: 18,
          tint: Color.White
        })
      }
      .width(28)
      .height(28)
      .backgroundColor(item.iconBg)
      .borderRadius(7)

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(item.label)
            .fontSize(AppFont.BodyL)
            .fontColor(AppTheme.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .flexShrink(1)
          if (item.id === 'achievements' && this.auth.isLoggedIn && this.medalService.ready &&
            this.medalService.selectedMedalId !== '') {
            Image(this.medalService.selected()?.badge)
              .width(20).height(20).objectFit(ImageFit.Contain).flexShrink(0)
              .accessibilityText(this.medalService.selected()?.name ?? $r('app.string.account_medal_list'))
          }
        }.width('100%').alignItems(VerticalAlign.Center)
        if (typeof item.subtitle !== 'string' || item.subtitle.length > 0) {
          Text(item.subtitle)
            .fontSize(AppFont.Caption)
            .fontColor(AppTheme.TextTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      ThemeIconComponent({ role: ThemeIconRole.ChevronRight, symbol: $r('sys.symbol.chevron_right'),
        iconSize: 24, tint: AppTheme.TextTertiary })
    }
    .width('100%')
    .padding({
      left: ROW_INDENT,
      right: ROW_INDENT,
      top: AppSpace.Sm,
      bottom: AppSpace.Sm
    })
    .constraintSize({ minHeight: 56 })
    .onClick(() => this.onItemTap(item.id))
  }
}
