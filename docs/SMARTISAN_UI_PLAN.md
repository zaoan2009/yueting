# Smartisan 思路整 App 布局规范（C + 1）

颜色继续跟随主题套装（`ThemeBundles` / `AppTheme` / `AppColor`），本规范只约束布局、字阶与控件层级。实现 token 见 `AppSpace` / `AppFont` / `AppLayout`（`entry/src/main/ets/theme/Theme.ets`）。

## 原则

1. 一屏一个主视觉（播放=封面，书架=书封，搜索=结果，首页=当前书单）。
2. 留白优先于堆叠：区块用 `AppSpace.Section`，页边用 `AppSpace.PageX`。
3. 字阶三级为主：主标题 / 正文 / 辅助（`HeroTitle`·`Title` / `Body`·`BodyL` / `Caption`）。
4. 主操作大且少；次要入口弱色、小图标，不与主视觉抢戏。
5. 装饰让位内容：主题暗纹保留，UI 壳变薄。
6. 动效短稳；播放页唱片旋转用属性动画（`AppLayout.VinylSpinMs`），无 JS 逐帧。

## 播放页（标杆）

竖屏自上而下：

1. 轻顶栏：返回 + 次要入口（换源 / 音量增幅 / 收藏 / 跳过片头片尾 / 目录 / 更多），透明图标。
2. **唱机主视觉**：对齐 [MusicPlayer-Smartisan](https://github.com/luospp/MusicPlayer-Smartisan) DiscView + CustTonearmView——`vinyl_lp`/`vinyl_veins` 黑胶分层 + 圆形内封 + 右上真实唱针素材（`VinylPlayerCover`）；15s/圈旋转、暂停抬臂归位；唱针角度 13°～30° 随进度（拖进度同步）；竖屏仅「顶栏 + 大唱片 + 唱片下曲名/作者 + 细进度 + 单行底栏」；播放页不展示书源名。整页背景走主题套装（`ThemeBackgroundComponent`），仅唱片内封适配当前封面，不用封面铺满整页氛围。
3. 书名 `HeroTitle` 加粗、章节 `Body` 辅助色；间距 `HeroGap`。
4. 细进度条高 `ProgressHeight` + 左右时间 `Caption`，紧贴曲目信息下方。
5. 主播控：上一章 / 播放 / 下一章 / 定时；播放键 `PlayGlyph` 最大。有声不在底栏放倍速与 ±15。
6. 次级工具：跳过与章节在顶栏；图标 `ToolGlyph`，未启用弱色。

横屏：左唱片（含曲目与进度）右控，右栏为同一主播控底栏。

迷你播控：圆封面静止 + 细进度环；少装饰，与全页转场衔接。

禁止：顶栏图标堆成工具条、次级工具与主播控同尺寸、炫技式乱转/弹跳封面。

## 主 Tab

- 首页：板块间距 `Section`；书卡两级信息（书名主、作者/来源辅）。
- 书架：宫格边距加大；列表行高 ≥ `ListRowMin`；分隔轻。
- 搜索：列表「封面 + 书名 + 一行辅文」；顶栏控件偏扁。
- 记录 / 我的：卡片间距 `Section`；入口行字阶统一；少分割线。

## 详情 / 设置 / 主题

- 详情动作行：加入书架、听/读为主视觉权重；目录、下载、换源、记录为次。
- 设置与主题：区块标题清晰，卡片内边距 ≥ `Md`；主题预览遵循同一留白。

## 验收

- 播放页一屏可读：封面 → 在听什么 → 能否播放。
- 切主题套装时布局不变、颜色仍变。
- 主路径搜 → 详情 → 听/读可用；竖横屏与紧凑窗可抽检。
