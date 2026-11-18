# 悦听音频源服务

可选的独立音频聚合服务，将来源的搜索、书籍、章节和播放地址统一为 HTTP API，并提供 Vue 运维后台。当前手机 App 在设备端处理用户导入的书源，没有接入本服务或配置其地址。

## 组成

- Express + TypeScript 标准 API
- SQLite WAL 缓存、来源版本和审计记录
- Reader/Legado 服务端音频规则引擎
- 免费听书王专有音频 API Provider（匿名会话、签名、令牌自动刷新）
- YCKCEO、AOAOSTAR、Yiove 网络目录每日同步
- Vue 3 运维后台
- Caddy HTTPS 入口

默认启用开放播客目录，LibriVox 公版音频目录保留为可选来源。阅读书源仅允许 `bookSourceType = 1`，
且只能由后台管理员导入。

“免费听书王”作为独立来源接入，不转换成 Legado JSON。服务器仅在配置 `GUOWEI_SIGNING_KEY` 时首次启用，
签名值属于部署环境配置，不得提交到仓库。

## 调用结构

服务端聚合已配置的阅读音频书源。搜索按来源并发、独立失败并按 `sourceUrl + bookUrl` 去重；详情、目录和播放解析仍按结果所属来源分发。

| 页面或流程 | 标准接口 | 主要数据表 |
| --- | --- | --- |
| API 调用方聚合搜索 | `GET /api/v1/audio-books/search` | `sources`、`books`、`cache_entries` |
| 书籍详情 | `GET /api/v1/audio-books/:id` | `books` |
| 章节目录 | `GET /api/v1/audio-books/:id/chapters` | `books`、`chapters` |
| 播放和下载前解析 | `POST /api/v1/audio-chapters/:id/resolve` | `chapters`、`sources` |
| 来源管理和检测 | `/api/admin/sources` | `sources`、`source_versions`、`health_events` |
| 操作记录 | `GET /api/admin/logs` | `audit_logs` |

标准书籍字段为 `id/title/author/narrator/cover/intro/category/chapterCount/totalDuration`；章节字段为
`id/bookId/title/index/duration`；播放解析返回 `url/headers/format/expiresAt`。公共 API 输出解析结果，
规则由服务端 Provider 和 Reader 引擎处理；手机 App 的本地规则导入与执行是独立流程。

## 本地开发

### 会员优惠签名核心（已停用）

App 已移除会员与 IAP。下列 `membership-offer` 代码仅保留在可选 `server/` 仓库中，不再被客户端调用；勿再部署到生产或配置 App 端点。

