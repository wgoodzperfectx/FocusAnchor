# UX V3.1 使用偏好页修订

日期：2026-11-01。依据：用户本轮对设置与偏好页的补充要求、UX V3.1 冻结草案及架构章程 v0.1。源码位于 `codex/workflow-v21` 的已授权 UX 集成工作区；原有多路线未提交改动仍保留，本轮未合并、提交或改写 Agent/同步/事务模块。

## 文件级影响

| 文件 | 变更 |
|---|---|
| `entry/src/main/ets/pages/SettingsPage.ets` | 将“个人信息”重构为“使用偏好”；删除头像卡、预设头像、相册选择及相关导入；保留昵称、语言、已有隐私授权和高级设置；展示无权威接口的项目为“待接入”。 |
| `entry/src/main/ets/pages/AppTabs.ets` | Home 右上角设置入口换为 P2 资源；监测入口读取 UI 显隐偏好。 |
| `entry/src/main/ets/services/UiPreferenceStore.ets` | 仅保存 Home 监测入口显隐；不控制监测服务、设备连接或生理状态。 |
| `entry/src/main/resources/base/media/brand_p2.jpg` | 原样复制用户指定 P2 图片作为设置入口；未对标志重新绘制或抠图。 |

## 路由与状态

- Home 的 P2 图标继续路由到 `pages/SettingsPage`；返回操作使用 Router.back。
- 昵称、语言、闪念记录授权、专注支持授权与既有隐私选项继续交由 `AppState.updateSettings` 保存。未修改 `AppSettings`、`StorageService` 或授权门控。
- 监测入口显隐由 `UiPreferenceStore` 独立保存；Home 可见时刷新。手表连接保持“未知”，不依赖本地监测开关推断已连接。
- 建议语气、提醒频率暂无生产消费接口，界面仅陈列“待接入”；不会保存无效值或假装影响 Agent/提醒。
- 旧年龄展示与头像数据字段仍保留在数据模型用于兼容历史数据，设置页不再显示头像选择功能。

## 接口缺口

1. Agent/工作流路线：建议语气的受控枚举、适用范围、来源与实际消费回执。
2. 提醒路线：提醒频率的持久化字段、有效调度行为与关闭/恢复规则。
3. 设备路线：可信手表连接状态及时间戳；设置页目前只能展示未知。
4. 隐私/数据：现有数据选项的实际用途说明及删除/导出能力需单独确认，不在 UI 层推断。

## 验证

- App HAP：`assembleHap --mode module -p module=entry@default -p product=default`，PASS；SDK 路径仅在构建进程环境变量设置，未改配置。日志：`D:/70_Competition/FocusAnchor/10_Codex/reports/ux-settings-build-20261101.log`。
- 自动化：`node --test tests/*.test.mjs`，178/178 PASS。日志：`D:/70_Competition/FocusAnchor/10_Codex/reports/ux-settings-tests-20261101.log`。
- `git diff --check`：无空白错误；只有已有文件换行符提示。
- 模拟器/真机：截至 2026-11-01 17:57（上海时间），Pura 90 Pro 手机镜像目录仍不存在，DevEco 下载暂存 ZIP 为 39,168,536 字节，最后写入时间 17:44；`hdc list targets` 返回 `[Empty]`。因此没有本机模拟器/真机运行结果。项目负责人选择云调试并提供录像，待录像回传后补充页面交互验收。

## 并行冲突

`AppTabs.ets` 与 `SettingsPage.ets` 是共享 UI 文件，与原 UX worktree 及工作流路线的改动存在文件级合并冲突可能。源工作区未提交，本轮改动需在正式合并前逐文件检查。没有改动工作流、协同、TaskFile、WatchSync、FormKit、生理推断、签名或 SDK 配置。
