# 银杏听书上架素材

应用名称统一为 **银杏听书**。本目录维护中文介绍、截图、隐私政策与上架清单；完整步骤见 [CHECKLIST.md](CHECKLIST.md)。

## 介绍与图片

- [zh-CN.json](zh-CN.json)：应用名称、一句话简介、完整介绍、新版本说明、截图顺序与建议隐私 URL。
- [introduction.txt](introduction.txt)：可直接复制到上架后台的纯文本（由导出脚本根据 `zh-CN.json` 生成）。
- [index.html](index.html)：公开展示页，汇总介绍、截图与隐私政策入口。
- [icon.png](icon.png)：1024 级应用图标，与安装包图标同源导出。
- [screenshots/](screenshots/)：当前版本手机实机截图（首页、书架、历史记录、关于）。
- [posters/](posters/)：平板 / 手表 / PC 示意海报，正式机型建议补拍后替换。
- [privacy.html](privacy.html)：可部署的隐私政策网页，正文与应用内资源一致。

更新应用内隐私或图标后，在仓库根目录执行：

```bash
python3 scripts/export-app-gallery.py
```

## 安装包

| 项 | 值 |
| --- | --- |
| 包名 | `com.yueting.listen` |
| 当前版本 | `0.0.2`（`versionCode` 2）；以 `CHANGELOG.md` 为准，运行 `node scripts/sync-version-from-changelog.cjs` 同步 |
| 最低系统 | HarmonyOS 6.0 / API 20 |
| 目标系统 | HarmonyOS 26.0.0 / API 26 |

调试 HAP 仅用于获授权设备。**市场上架必须上传发布签名的 release APP**，构建与核对步骤见 [CHECKLIST.md](CHECKLIST.md) 的 B/C 节。历史邀测包说明见仓库 `artifacts/`（本机保留，不入库）。

## 平台同步

在 AppGallery Connect 同一应用条目中：

1. 替换名称、简介、介绍、新版本说明与截图为本目录内容。
2. 将 `privacy.html` 部署到公网后填入隐私政策字段（Caddy 已预留 `/yueting/` 路径）。
3. 上传 release 签名 APP；保留原有应用标识与 Client ID。

软件资质中的法定软件名称也需与「银杏听书」相对应；资质变更由发证机构或平台办理。
