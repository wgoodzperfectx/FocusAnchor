# FocusAnchor UX V2 验收记录

日期：2026-10-15。范围：`Huang-A/pig-master`，依据 `docs/FocusAnchor_UX_V2_review_framework.md`。此记录把静态逻辑、构建与设备交互分开，不把编译成功视为跨端闭环。

## 验证环境

- `node --test tests/*.test.mjs`：纯状态逻辑和同步协议测试，**29/29 通过**。
- entry：DevEco SDK `D:/Tools/DevEco26/DevEco Studio/sdk` 的 hvigor `assembleHap --mode module -p module=entry@default -p product=default`。
- entry：上述命令显示 `hvigor BUILD SUCCESSFUL in 8 s 159 ms`。
- wear：同一 hvigor 的 `assembleHap --mode module -p module=wear@default -p product=default`，**BUILD SUCCESSFUL**。两个模块顺序构建；并发构建曾收到 daemon busy，顺序重试通过。
- `git diff --check`：退出码 0；仅有已有文件的 LF/CRLF 提示。
- `hdc list targets` 返回 `[Empty]`；本机暂无可用模拟器或真机目标。需要设备的项目保持“已实现未验证”。

## 入口迁移

| 原入口 | UX V2 入口 | 状态 |
| --- | --- | --- |
| Home 上的平级 Guide 按钮 | Task 列表中的“帮我拆成第一步”，规则建议经用户确认 | 已实现且构建验证 |
| Home 重复时钟 | 顶栏系统时间 | 已实现且构建验证 |
| Home 平级 Focus 按钮 | Home 当前任务主按钮、底部 Focus 入口 | 已实现且构建验证 |
| GuidePage 直接改 `focusStep.status` | `ActionEventService` 统一裁决，FocusSession 独立保存 | 已实现且逻辑测试验证 |
| 手表整包 `tasks_sync` 回写 Action | 手机投影 + 手表事件/ACK | 已实现未设备验证 |

## 数据模型和接口

- `StudyTask.focusStep` 仍为兼容载体，补 `taskId/actionId/order/revision/generationSource/appliedEventIds`；旧步骤按任务 ID 与旧更新时间确定性迁移。`FocusAction` 公开状态为 `ready/in_progress/completed`。
- `ActionEvent` 携带 `eventId/taskId/actionId/baseRevision/type/origin/createdAt`，手机 `ActionEventService.apply` 裁决并持久化后刷新卡片和手表；`change` 无真实候选时返回 `needs_step`。
- `FocusSession` 单独记录 `sessionId/taskId/actionId/status/updatedAt`；暂停和继续只影响会话。
- `FlashNote` 用 `flashId` 去重、归档墓碑；转任务使用 `from_flash_${flashId}` 的编码形式，任务文件先写，关联随后写。
- 复用 `TaskFileService`、`AppState`、`WatchSyncService`、`FocusCardService`、现有 FormAbility、`proposeFirstStep()` 规则分支、语音入口与设置/提醒。新增 `ActionLogic`、`ActionEventService`、`FocusSessionService`、`FlashNoteService` 及独立协议纯函数。

### 变更文件清单（按职责）

| 范围 | 本轮文件 |
| --- | --- |
| 类型、迁移、事件与会话 | `models/AppTypes.ets`、`services/ActionLogic.ts`、`TaskFileService.ets`、`ActionEventService.ets`、`FocusSessionLogic.ts`、`FocusSessionService.ets`、`AppState.ets` |
| 卡片/手表协议 | `FocusCardService.ets`、`FocusTaskCardAbility.ets`、`FocusTaskCard.ets`、`CardEventProtocol.ts`、`WatchSyncService.ets`、`SyncProtocol.ts`、`wear/.../Index.ets`、`WearSyncQueue.ts` |
| 闪念 | `FlashNoteLogic.ts`、`FlashNoteService.ets`、`WearFlashNoteService.ts`、`AppState.ets`、双端页面 |
| 入口与视觉 | `pages/Index.ets`、`AppTabs.ets`、`FocusPage.ets`、`DomainServices.ets`、`CompanionLogic.ts`、`CompanionVisualService.ets`、双端 `fa_*.png` |
| 验证 | `tests/*.test.mjs`、本验收记录 |

## 九态素材

imagegen 内置工具以 `8_Drive/图标和logo` 两张原始状态板为参考，分别去除标题和字幕并生成等分精灵板，再机械裁为独立资源。最终完整精灵板保存在 `8_Drive/图标和logo/FocusAnchor-heart-rate-six-state-source-v2.png` 和 `FocusAnchor-companion-three-state-source-v2.png`；九张资源各自保存于 entry、wear 的 `resources/base/media/fa_*.png`。生成提示分别要求保留六种/三种黑色角色和绿色符号、原顺序、纯白方形格、无文字或新增元素。已目视检查连接中、已停止、专注稳定的独立裁片。

| 状态 | 资源 ID |
| --- | --- |
| CONNECTING / READING / MONITORING | `fa_monitor_connecting` / `fa_monitor_reading` / `fa_monitor_monitoring` |
| SIGNAL_UNSTABLE / RECONNECTING / STOPPED | `fa_monitor_signal_unstable` / `fa_monitor_reconnecting` / `fa_monitor_stopped` |
| STABLE / FLUCTUATING / SUPPORT_REQUESTED | `fa_companion_stable` / `fa_companion_fluctuating` / `fa_companion_support_requested` |

`CompanionLogic.selectCompanionVisual()` 在模拟、缺失、过期或异常监测时优先显示监测图。当前心率流为随机模拟，`HeartRateSnapshot.isSimulated=true`，界面明确标注模拟，也不根据该流显示“优秀/专注稳定”。

## T01–T12

| 用例 | 当前状态 | 证据与限制 |
| --- | --- | --- |
| T01 无 Task 不虚构 Action | 已实现且逻辑测试验证 | `action-logic.test.mjs`；Home 空态已构建，设备页面待验 |
| T02 拆分并持久化 | 已实现未设备验证 | Task 规则建议与确认代码、entry 构建；点击流程待验 |
| T03 Agent 不可用如实降级 | 已实现未设备验证 | UI 明示“规则建议”；`proposeFirstStep()` 同意与安全门控，设备待验 |
| T04 四端同一 actionId | 已实现未设备验证 | 同一任务投影与卡片/手表契约；跨端页面待验 |
| T05 卡片/手表完成及重复幂等 | 已实现且逻辑测试验证 | `action-events`、`sync-protocol`、`card-event` 测试；设备传输待验 |
| T06 换一步/暂停不误完成 | 已实现且逻辑测试验证 | `action-events`、`focus-session` 测试；设备操作待验 |
| T07 手表闪念进入 Focus | 已实现且逻辑测试验证 | 手表本地队列、独立 KV/ACK、手机落盘后确认与 Focus 列表刷新；设备传输待验 |
| T08 转任务不重复 | 已实现且逻辑测试验证 | `flash-note.test.mjs`，任务文件确定性 ID；设备点击待验 |
| T09 断连/权限/信号状态 | 接口存在但未接通 | 九图资源与纯映射测试；现有工程缺真实心率状态源，手机当前只显示模拟/停止，手表显示停止/重连；真实断连/信号差需设备接入与核查 |
| T10 重连重发去重 | 已实现且逻辑测试验证 | 手表 Action 队列协议测试；断连真机待验 |
| T11 心率不伪造专注状态 | 已实现且逻辑测试验证 | `companion-state.test.mjs`，随机样本显式标模拟 |
| T12 原功能无回归 | 已实现未设备验证 | 未移除设置、提醒、语音、悬浮球、账户入口；全量点击待验 |

## 集成边界与剩余验证

本轮只在 `Huang-A/pig-master` 的已接入卡片上扩展绑定和事件，不合并 `Zeng-C` 独立元服务工程。原卡片接口没有接入遗漏；新增冲突点是旧卡片按钮缺 Action 身份，现已在 FormAbility 校验并刷新。卡片、手表、断连恢复、圆形屏幕安全区、任务编辑兼容与页面点击仍需 DevEco 模拟器或真机逐项执行并留截图。手表旧任务 CRUD 暂提示在手机编辑，以避免整包回写覆盖 Action。真实心率传感器、手表语音/物理键闪念入口不在当前可验证范围。当前代码位于带有原有未提交改动的共享工作区；没有把预存改动重置或混入提交。
