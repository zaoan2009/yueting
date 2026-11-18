# 主题：银杏默认 + 全局自定义

状态：内置仅保留银杏（`ginkgo-winter`）；主题页支持全局背景图与全局色板（背景/表面/文字/强调）。银杏默认底图为生成插画（借鉴参考构图：天青、银杏枝叶、坡上小憩的孩子与猫；非用户截图原图）；桌面播放卡片同步银杏色、播放态强化金色。桌面应用图标固定虎图，阅读纸张配色独立。

## 范围

| 项 | 行为 |
| --- | --- |
| 内置默认 | 仅银杏；旧套装 ID（default/paper/frost/ink/ember）读取时迁到银杏 |
| 自定义色板 | 全局一套：`backgroundColor` / `surfaceColor` / `textColor` / `accentColor`；空串用银杏资源色 |
| 自定义背景图 | 相册选图复制到 `files/theme_bg`；有图时覆盖银杏暗纹；**不进**本地/云备份 |
| 材质 | 仍由设置页三档材质控制，不按模块拆分 |
| 桌面图标 | 默认闭眼微笑猫；播放中切换备用图标厌世猫（API 26+ `alternateIcons.playing`） |
| 功能图标 | `ThemeIcons` 使用 `theme_ginkgo_*` 可染色银杏线稿（底栏、搜索/筛选/宫格列表/分类/右箭头，以及「我的」书源/导入/下载/设置/成就/主题/关于）；`paper()` 方法名保留兼容 |
| 「我的」子页 | 账号、设置、主题、书源、导入、下载、成就、关于及隐私/合规/开源均叠 `ThemeBackgroundComponent`，文字/表面/分割线走 `AppTheme`；路由 `ProfileMenuDestination` 背景为透明以免挡住底图 |

## 数据

`app_theme_preferences`（`AppThemeSelection`，`schemaVersion=2`）：

- `themeBundleId`：恒为 `ginkgo-winter`
- `accentColor` / `materialStyle`
- `backgroundColor` / `surfaceColor` / `textColor`
- `customBackgroundName`：相对文件名；文件缺失时 UI 回退银杏暗纹

v1 记录与旧 `accent_color`/`material_style` 兼容；备份字段 `themeSelection` 携带色值，不含图片字节。

## 入口

`ThemePage` → `ThemeBundleComponent`：银杏预览与恢复默认；自定义区选图/清图、色点与 `#RRGGBB`、应用色板。`PreferenceService.setThemePalette` / `setCustomBackgroundName` / `restoreDefaultTheme` 串行写入，成功后发布 `AppAppearance`。
