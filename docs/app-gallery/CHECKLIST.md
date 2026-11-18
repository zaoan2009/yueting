# 悦听 · 华为应用市场上架清单

包名 `com.yueting.listen`。本清单区分「仓库已完成」与「需你在 AGC / 本机手工完成」。

## A. 仓库内已完成（可随版本提交）

- [x] 应用内文案与产品一致：无漫画阅读入口、关于页无「使用说明」、检查更新无「前往华为应用市场」旁注
- [x] 「阅听记录」→「历史记录」；首页「精品推荐 / 分类」顺序已调整
- [x] 上架介绍 `zh-CN.json` / `introduction.txt` / `index.html` 已去掉漫画表述并更新版本说明
- [x] 隐私政策与应用内一致：`python3 scripts/export-app-gallery.py` 生成 `privacy.html`
- [x] 手机截图已按实机重采（首页、书架、历史记录、关于）；应用版本现为 0.0.1
- [x] 图标 `icon.png` 与安装包同源导出
- [x] Caddy 配置预留 `/yueting/*` 静态托管隐私政策与介绍页（见 `server/deploy/Caddyfile`）

## B. 本机发布包（上传前必做）

0. 运行 `node scripts/bump-version.cjs --auto`（或 `-m "说明"`）自动升版并写 CHANGELOG；再执行 `python3 scripts/export-app-gallery.py`（仅上架素材需要时）。
1. 在 DevEco Studio 为 **release** 产品配置**正式签名**（发布证书 + Profile），写入本机 `build-profile.json5` 的 `signingConfigs`（勿提交密钥到仓库）。
2. 在 AGC 同一应用（Client ID `6917621950587862943`）登记**发布签名**的 SHA256 证书指纹。
3. 用正式工具链构建：

```bash
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents
export JAVA_HOME="$DEVECO_HOME/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$DEVECO_HOME/tools/node/bin:$PATH"
node "$DEVECO_HOME/tools/hvigor/bin/hvigorw.js" \
  assembleApp --mode project -p product=release -p buildMode=release --no-daemon
```

4. 上传前核对：所有 HAP 的 `apiReleaseType = Release`；QuickJS HAR 亦为正式工具链产物。
5. 产物放本机 `artifacts/releases/vX.Y.Z/`（目录已 gitignore），保留 `.app` 与校验摘要。  
   本轮已打出**未签名**包：`build/outputs/release/HarmonyOS-book-release-unsigned.app`（构建日志有 `No signingConfig found for product release`）。**不可上传市场**，需补正式签名后重打。

## C. AppGallery Connect 后台

1. 应用名称、法定软件名称均对应「悦听」（资质变更按平台流程办理）。
2. 一句话简介、完整介绍、新版本说明：复制 `introduction.txt` / `zh-CN.json`。
3. 隐私政策 URL：部署 `privacy.html` 后填写公网地址（推荐 `https://你的域名/yueting/privacy.html`；仓库默认示例见 `zh-CN.json` 的 `privacyPolicyUrl`）。
4. 上传手机截图：`screenshots/02-home.png`、`03-library.png`、`04-history.png`、`01-about.png`（顺序同 `zh-CN.json`）。平板/手表/PC 海报见 `posters/`，按设备类型选填。
5. 上传 release 签名的 APP，选择公开或邀测。
6. 年龄分级、权限说明、内容来源说明与应用内「内容说明 / 使用约定」一致：不托管正文与音频，书源由用户导入。

## D. 上架后回归

- [ ] 未安装用户从市场安装成功
- [ ] 华为账号登录（正式指纹）
- [ ] 「检查更新」能打开本应用市场详情页
- [ ] 云备份开关与隐私政策链接可访问
- [ ] 书源导入 → 搜索 → 详情 → 阅读/播放主路径

## E. 开源合规（基于上游 GPL 引擎）

- [x] 应用内「开源与第三方组件」首节为开源致谢（开源轻页 / qingye-reader、legado-harmony、harmony-book-source-engine）
- [x] 关于页底部有非官方版提示，并可进入开源声明
- [x] 仓库 `THIRD_PARTY_NOTICES.md`、随包 `rawfile/licenses/`、`README.md` 已写明开源轻页致谢
- [ ] 上架/分发时按 GPL-3.0 提供对应源码获取方式（源码仓库、随包或书面要约）；不能把整包标成 MIT
- [ ] 市场文案用「悦听」品牌，致谢放在开源声明，勿暗示本应用即开源轻页官方版

## F. 尚未由仓库代替的事项

| 项 | 说明 |
| --- | --- |
| 正式签名材料 | 仅本机 DevEco / AGC 证书中心 |
| 软件著作权等资质更名 | 发证机构或平台 |
| 服务器静态页实际上线 | 需有部署权限的主机执行 `server/deploy` 更新 |
| 平板/手表/PC 新截图 | 现有 `posters/` 为示意，正式机型建议补拍 |
| 公开版版本号 | 以 `CHANGELOG.md` 为准；当前 `0.0.2` / `versionCode` 2，发版前运行 `node scripts/sync-version-from-changelog.cjs` |
