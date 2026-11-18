# 悦听

悦听，让聆听与阅读更从容。

面向 HarmonyOS 6.0 及以上手机、平板和电脑的本地优先听书与小说阅读应用。书源由你自己导入，规则在设备上执行；本地电子书和音频也可以直接放进书架。进度、历史和备份都留在本机（或你的华为云空间），不依赖悦听服务器。

当前版本：**0.0.1**

## 功能概览

- **书源**：导入 JSON、链接或通过系统分享打开；支持分组、启停、锁定、批量测试。可搜索、看发现、读正文、听有声，具体能力取决于书源规则。
- **本地文件**：TXT / EPUB / MOBI / HTML / HTM、常见音频格式，以及 ZIP；可用系统「使用悦听打开」直接导入。
- **阅读**：字号、行距、字重、主题与背景、字体导入、书签、替换净化、章节进度恢复。
- **听书**：倍速、片头片尾跳过、睡眠定时、锁屏与系统媒体控制、桌面播放卡片；在线小说支持本机 TTS 朗读。
- **发现**：首页精品推荐与分类来自你启用的书源发现页。
- **书架与备份**：收藏、历史记录、收听统计；支持本地备份，登录华为账号后也可备份到个人云空间。

悦听不内置在线书库，也不提供书源订阅。正文和音频来自你导入的书源或本地文件。

## 开源说明

书源解析基于 **开源轻页** 相关工程（GPL-3.0）固定版本迁入并适配，感谢原作者与贡献者：

- 开源轻页：[qingye-reader](https://github.com/wip3l/qingye-reader)
- 宿主 / 调度辅助：[legado-harmony](https://github.com/wip3l/legado-harmony)
- 解析内核：[harmony-book-source-engine](https://github.com/wip3l/harmony-book-source-engine)

页面、书架、阅读器和播放器由悦听维护。悦听不是开源轻页官方发行版。

完整第三方声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，轻页同步说明见 [docs/LIGHT_SOURCE_SYNC.md](docs/LIGHT_SOURCE_SYNC.md)。应用内「关于 → 开源与第三方组件」有同等说明。

## 内容约定

悦听不内置、不托管、不分发小说正文或音频资源。请只导入你有权使用的文件与书源，并遵守相关法律与来源站点条款。应用按你配置的规则访问与解析，不以破解付费内容、绕过访问控制或批量抓取受保护内容为目标。

## 开发与上架

| 项 | 值 |
| --- | --- |
| 包名 | `com.yueting.listen` |
| 版本 | `0.0.1`（`versionCode` 1） |
| 最低系统 | HarmonyOS 6.0 / API 20 |
| 目标系统 | HarmonyOS 26.0.0 / API 26 |

- 页面与交互：[docs/APP_UI.md](docs/APP_UI.md)
- 书源规则：[docs/BOOK_SOURCE_RULES.md](docs/BOOK_SOURCE_RULES.md)
- 应用市场上架素材：[docs/app-gallery/](docs/app-gallery/)
