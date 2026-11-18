/** 主题图标按用途解析；页面无需绑定具体素材文件。 */
export enum ThemeIconRole {
  None,
  Search,
  Filter,
  Grid,
  List,
  ChevronRight,
  Home,
  Shelf,
  Record,
  Profile,
  Category,
  RuleSource,
  Import,
  Downloads,
  Settings,
  Achievements,
  Theme,
  About
}

export class ThemeIcons {
  /** 银杏可染色线稿；方法名保留 paper 以兼容旧调用。 */
  static paper(role: ThemeIconRole): Resource {
    switch (role) {
      case ThemeIconRole.Search: return $r('app.media.theme_ginkgo_search');
      case ThemeIconRole.Filter: return $r('app.media.theme_ginkgo_filter');
      case ThemeIconRole.Grid: return $r('app.media.theme_ginkgo_grid');
      case ThemeIconRole.List: return $r('app.media.theme_ginkgo_list');
      case ThemeIconRole.ChevronRight: return $r('app.media.theme_ginkgo_chevron_right');
      case ThemeIconRole.Home: return $r('app.media.theme_ginkgo_home');
      case ThemeIconRole.Shelf: return $r('app.media.theme_ginkgo_shelf');
      case ThemeIconRole.Record: return $r('app.media.theme_ginkgo_record');
      case ThemeIconRole.Profile: return $r('app.media.theme_ginkgo_profile');
      case ThemeIconRole.RuleSource: return $r('app.media.theme_ginkgo_rule_source');
      case ThemeIconRole.Import: return $r('app.media.theme_ginkgo_import');
      case ThemeIconRole.Downloads: return $r('app.media.theme_ginkgo_downloads');
      case ThemeIconRole.Settings: return $r('app.media.theme_ginkgo_settings');
      case ThemeIconRole.Achievements: return $r('app.media.theme_ginkgo_achievements');
      case ThemeIconRole.Theme: return $r('app.media.theme_ginkgo_theme');
      case ThemeIconRole.About: return $r('app.media.theme_ginkgo_about');
      default: return $r('app.media.theme_ginkgo_category');
    }
  }
}
