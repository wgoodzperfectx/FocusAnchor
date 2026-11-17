# Watch UX V3.3 P0 文件计划与资源缺口

基准：`6_文档/技术框架/FocusAnchor_Watch_UX_V3.3_页面冻结与动态角色规范.md`，手机 UX V3.1 品牌视觉，架构章程 v0.1。
隔离分支：`codex/watch-ux-v3-3`，从干净的 V3.2 提交 `5cf6ebd` 建立；主 worktree 与 UX V3.1 的未提交 Wear 文件未改动。

| 文件 | P0 修改 | 状态来源/边界 |
|---|---|---|
| `wear/src/main/ets/pages/Index.ets` | 当前一步、闪念双页骨架；单一快捷导航；次级心率/设置；去冗余文字 | `tasks_sync` 手机投影、原有本地闪念 preferences/KV/ACK；不写传输 |
| `wear/src/main/ets/pages/FocusPage.ets` | 心率次级页；删除 More→设置；读数/来源/未知态 | 仅消费可验证快照；无生产者时未知 |
| `wear/src/main/ets/pages/SettingsPage.ets` | 语言、权限和同步详情，弱入口 | 已有本地语言设置与未知设备标记 |
| `wear/src/main/ets/services/WearUiState.ts` | 冻结只读 interaction/monitor/companion/sync ViewState 与标注 fixture | 手机任务权威；监测与 P3 状态尚无生产契约 |
| `wear/src/main/ets/services/WearVisualService.ets`、新共用伙伴组件 | 同源状态资源、Motion A | 只根据输入状态切换，动画不驱动业务状态 |
| `wear/src/main/resources/base/media/` | 透明正式角色资源，去掉 PNG 自带白底 | 保留眼睛、绿脚及正式轮廓；素材前后逐张校验 |
| `tests/`、本文件和验收记录 | T01–T14 UI 与状态证据 | fixture 与真实链路分开报告 |

当前资源：8 张 `status_*` 为 320×240 RGBA，alpha 0–255，可直接复用。6 张 `fa_monitor_*` 与 3 张 `fa_companion_*` 均为 256×256 RGBA，但 alpha 固定 255；源目录只有整版状态板，没有独立透明单态资源。P0 不能直接把这 9 张白底图作为最终画面。P1 Motion B 缺少独立透明眼睛、绿脚、状态符号和可用短帧；在设计素材确认前只做 Motion A 的状态切换与轻过渡。

接口缺口：手机当前未稳定生产 `currentActionId`、监测六状态、P3 可信陪伴状态；Wear 只能消费可选状态，不能宣布 Agent、心率、同步真值。同步/ACK、任务事务、权限和生理采集仍属其他路线。
