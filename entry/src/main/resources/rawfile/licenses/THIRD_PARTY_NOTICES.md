# 第三方软件声明（随包摘要）

完整说明见仓库根目录 `THIRD_PARTY_NOTICES.md`。本文件随安装包提供，便于用户在无源码树时查阅。

## 开源致谢：开源轻页（GPL-3.0）

悦听书源解析能力基于 **开源轻页** 相关工程固定版本迁入并适配（非官方发行版），感谢原作者李其健及贡献者。

- 开源轻页：https://github.com/wip3l/qingye-reader
- 宿主与调度辅助：https://github.com/wip3l/legado-harmony
- 解析内核：https://github.com/wip3l/harmony-book-source-engine

版权与 NOTICE 见 `third_party/light-source/NOTICE`，许可证全文见 `third_party/light-source/LICENSE`（GPL-3.0）。固定提交与文件归属见 `third_party/light-source/upstream.json`。

页面、书架、阅读器、播放器为悦听实现。含该引擎的发行包须遵守 GPL-3.0，不能将应用整体声明为 MIT；对应源码须按 GPL 要求提供。

## QuickJS / ohos_quickjs / N-API / CryptoJS

- QuickJS（MIT）：https://bellard.org/quickjs/
- @devzeng/quickjs / ohos_quickjs（MIT）：https://github.com/hhtczengjing/ohos_quickjs
- OpenHarmony / Huawei N-API 封装（Apache-2.0）
- CryptoJS 4.2.0 子集（MIT）：https://github.com/brix/crypto-js

许可全文见同目录其他文件及仓库 `third_party/quickjs/`、`third_party/crypto-js/`。

## 仓颉运行时 / LLVM libc++

见仓库 `THIRD_PARTY_NOTICES.md` 与 `rawfile/third_party/cangjie/`。
