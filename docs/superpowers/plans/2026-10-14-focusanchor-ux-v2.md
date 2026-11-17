# FocusAnchor UX V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让手机 Home、Task、Focus、已接入卡片和手表围绕同一个真实 Action 工作，并让手表闪念进入 Focus 收件箱。

**Architecture:** 在现有 `StudyTask.focusStep`、任务文件和 `WatchSyncService` 上增量扩展。主体持久化并裁决 Action 事件；卡片和手表提交带身份与版本的操作，再读取主体投影。闪念使用同一 KV store 的独立键和手机本地文件。

**Tech Stack:** HarmonyOS Stage、ArkTS/ArkUI、Form Kit、distributedKVStore、TaskFileService、Hypium。无新增第三方依赖。

**Spec:** `docs/superpowers/specs/2026-10-14-focusanchor-ux-v2-design.md`

## Global Constraints

- 仅修改 `Huang-A/pig-master`；不改 bundle、签名、SDK 或 `Zeng-C`。
- 保留已有设置、提醒、悬浮球、语音、账户功能和卡片接入文件；在当前未提交文件上增量修改，不重置、不覆盖。
- Agent 规则分支必须标 `rule`；没有可调用 Agent 时呈现明确降级。随机 BPM 必须标 `isSimulated`，不可推断陪伴状态。
- 不新增原始健康数据上报，不读取其他 App 的屏幕内容；保留用户同意与 Agent 安全门控。
- TaskFileService 的任务文件是持久化状态源；先落库，再刷新卡片和手表。
- 每个任务完成后只检查本任务的测试/构建及 `git diff --check`；构建、模拟器、真机结果分开记录。当前仓库没有现成测试目录和命令行 hvigor wrapper，先建立 Hypium 测试目标并确认 DevEco Studio 实际运行入口。
- 当前共享 `master` 含他人未提交卡片改动。只审查和记录本任务 diff；不得顺手提交或暂存他人文件。稳定基线形成后再按任务提交。

## File Map

| 文件 | 责任 |
| --- | --- |
| `entry/src/main/ets/models/AppTypes.ets` | Action、FlashNote、FocusSession、监测与陪伴类型 |
| `entry/src/main/ets/services/ActionEventService.ets`（新） | 旧步骤归一化、状态转移、持久化 eventId 去重和冲突结果 |
| `entry/src/main/ets/services/FlashNoteService.ets`（新） | 手机闪念文件、去重、归档和确定性转任务 |
| `entry/src/main/ets/services/AppState.ets`、`TaskFileService.ets` | 主体持久化事务入口和旧数据迁移 |
| `entry/src/main/ets/services/WatchSyncService.ets`、`wear/src/main/ets/services/WearSyncQueue.ets`（新） | 复用 KV store 交换步骤事件、确认和闪念 |
| `entry/src/main/ets/services/FocusCardService.ets`、`entry/src/main/ets/formability/FocusTaskCardAbility.ets`、`entry/src/main/ets/widget/pages/FocusTaskCard.ets` | 卡片投影及带版本按钮事件 |
| `entry/src/main/ets/pages/Index.ets`、`AppTabs.ets`、`FocusPage.ets`、`entry/src/main/ets/common/LocaleHelper.ets` | Home/Task/Focus 与文案 |
| `wear/src/main/ets/pages/Index.ets`、双端 `resources/base/media` | 手表任务和闪念入口、九态图 |
| `entry/src/ohosTest/ets/test`（新） | 可在 Hypium 中运行的纯状态/迁移/幂等测试 |

## Review Focus

1. 旧任务没有 `actionId`：两次加载必须给同一步相同 ID，不能重复创建 Action（Task 1 测试）。
2. 卡片完成的是过时 actionId：主体拒绝操作并返回当前状态（Task 2 测试）。
3. 手表离线事件重发：只应用一次，收到确认前保持待同步（Task 3 测试）。
4. 闪念转任务在两次文件写入间中断：重试后仍只有一个 taskId（Task 4 测试）。
5. 模拟/过期 BPM：不能显示真实监测或“专注稳定”（Task 7 测试）。

## Task 1：Action 契约与旧数据迁移（P0）

**Files:** 修改 `models/AppTypes.ets`、`services/TaskFileService.ets`；新建 `services/ActionEventService.ets`、`entry/src/ohosTest/ets/test/ActionContract.test.ets` 及 Hypium 必需的测试配置。

**Interfaces:** `FocusAction` 含 `taskId/actionId/text/status/order/updatedAt/revision/generationSource`；`normalizeFocusAction(task: StudyTask): FocusAction | undefined`；`TaskFileService.loadTasks()` 返回已迁移并持久化的任务。

- [ ] 写失败测试：旧 `focusStep` 两次加载得到同一 `actionId`、`revision=1`、`generationSource='legacy'`；无任务或无步骤返回 undefined；旧 `paused` 归一为进行中。
- [ ] 在 DevEco Studio 运行 `entry` 的 Hypium 测试目标，确认测试因缺接口失败；记录实际运行命令/目标名。
- [ ] 实现类型和确定性迁移；只有实际存在的旧步骤才生成 Action；任务文件写回发生在下游刷新前。
- [ ] 复跑该测试目标；检查 `git diff --check` 和旧任务 JSON 的兼容性。

## Task 2：主体 Action 事件裁决与会话（P0）

**Files:** 修改 `services/ActionEventService.ets`、`services/AppState.ets`；新增 `services/FocusSessionService.ets`、`entry/src/ohosTest/ets/test/ActionEvents.test.ets`。

**Interfaces:** `ActionEvent = { eventId, taskId, actionId, baseRevision, type, origin, createdAt }`；`ActionEventService.apply(context: common.Context, event: ActionEvent): Promise<ActionEventResult>`；`ActionEventResult` 明确 `applied/duplicate/conflict/missing/needs_step` 与当前 revision。`FocusSessionService.start/pause/resume` 以 actionId 绑定会话。

- [ ] 写失败测试：READY→ACTIVE→DONE；重复 eventId 无二次 revision；旧 actionId 或 baseRevision 冲突不修改任务；换一步与暂停不完成 Action。
- [ ] 运行测试确认失败。
- [ ] 主体核验事件后持久化任务与已处理 eventId，再触发卡片/手表刷新；会话独立存储。换一步无真实候选时返回 `needs_step`，不生成占位文本。
- [ ] 复跑测试；核对 `TaskFileService` 写失败不会触发成功刷新。

## Task 3：卡片与手表事件通道（P0）

**Files:** 修改 `services/FocusCardService.ets`、`formability/FocusTaskCardAbility.ets`、`widget/pages/FocusTaskCard.ets`、`services/WatchSyncService.ets`、`wear/src/main/ets/pages/Index.ets`；新建 `wear/src/main/ets/services/WearSyncQueue.ets` 与 `entry/src/ohosTest/ets/test/SyncProtocol.test.ets`。

**Interfaces:** 卡片绑定含 `taskId/actionId/revision`；卡片消息提交 `ActionEvent`，eventId 由 actionId、revision、操作类型确定，重复点按保持同一 ID。复用 `focux_watch_sync`，新增 `action_events_sync` 与 `action_acks_sync` 键；手表队列提供 `enqueue(event)`、`pending()`、`ack(eventId)`。

- [ ] 写失败测试：重复完成、旧卡片按钮、断连重发、确认前后同步提示，以及手表旧整包不得覆盖较新 Action。
- [ ] 运行测试确认失败。
- [ ] 卡片复用当前 FormAbility 和刷新接口，仅增加字段及统一裁决调用。手表步骤按钮写本地事件队列，经 KV 发送；主体回写确认，手表收到确认后出队。迁移期间手表任务编辑不得用整包覆盖主体 Action；保留入口时显示可理解的待同步/不可用结果。
- [ ] 复跑测试；在 DevEco 分别构建 entry 和 wear；检查卡片声明、消息解析、空状态和 `git diff --check`。

## Task 4：闪念收件箱数据闭环（P0）

**Files:** 新建 `services/FlashNoteService.ets`、`wear/src/main/ets/services/WearFlashNoteService.ets`、`entry/src/ohosTest/ets/test/FlashNote.test.ets`；修改 `services/WatchSyncService.ets`、`services/AppState.ets`、`wear/src/main/ets/pages/Index.ets`。

**Interfaces:** `FlashNote` 用 `flashId` 去重；手机用 `flash_notes.json`；KV 独立键 `flash_notes_sync`、`flash_acks_sync`；`AppState.convertFlashToTask(flashId): Promise<string | undefined>` 使用 `from_flash_${flashId}` 作为确定性 taskId。

- [ ] 写失败测试：手表先本地保存并标待同步；相同 flashId 重收不重复；收件箱到达不改变当前 Action；转换重试不重复创建 Task；归档墓碑不因重播复活。
- [ ] 运行测试确认失败。
- [ ] 实现本地保存、KV 同步/确认、手机去重和显式转换；复用现有任务创建与持久化入口，不把 Agent `ThoughtRecord` 伪装为手表记录。
- [ ] 复跑测试；检查离线和重连路径的错误提示与 `git diff --check`。

## Task 5：Home 与 Task 入口（P0）

**Files:** 修改 `pages/Index.ets`、`pages/AppTabs.ets`、`common/LocaleHelper.ets`；必要时修改 `components/FloatBall.ets` 的回调，不改变语音能力。

**Interfaces:** `HomeTab` 只消费 AppState 的当前 Task/Action/状态；`TasksTab` 的拆分按钮调用现有可调用 Agent 接口，缺失时明确展示 `proposeFirstStep()` 规则降级并待用户确认后保存，`generationSource='rule'`。

- [ ] 写页面验收步骤 T01–T03：无任务、有任务无步、READY/ACTIVE、Agent 不可用；记录预期文案及导航目标。
- [ ] 改造底部 Home/Task/Focus 入口和 Home 卡片；去掉 Guide 主入口、重复时钟、平级按钮；设置、提醒及悬浮球保持可达。
- [ ] Task 语音仅填入同一编辑流程，已有优先级/Deadline 保持；拆分结果展示来源、等待/失败状态，禁止固定占位 Action。
- [ ] 在模拟器或真机执行 T01–T03/T12；构建 entry，并记录无法运行的项。

## Task 6：Focus 工作台与闪念 UI（P0）

**Files:** 修改 `pages/FocusPage.ets`、`pages/Index.ets`、`common/LocaleHelper.ets`；必要时新增小型收件箱组件。

**Interfaces:** 从 AppState 读取当前 Action/FocusSession 和 FlashNote；开始/暂停/继续/完成走 Task 2 的主体事件入口；转任务走 Task 4 的幂等方法。

- [ ] 写页面验收步骤 T04、T06–T08：同一 actionId、暂停不完成、闪念默认折叠、新条目不抢焦点、显式转换一次。
- [ ] 复用既有 Focus 视觉与有效会话能力，补任务/步骤/会话操作和闪念收件箱；删除走归档墓碑，转换成功显示关联任务。
- [ ] 在模拟器或真机执行页面验收；构建 entry，记录未验证平台能力。

## Task 7：九态资源与可信状态显示（P1）

**Files:** 修改 `models/AppTypes.ets`、`services/DomainServices.ets`、`services/XiaoyiBridge.ets`、`pages/AppTabs.ets`、`pages/FocusPage.ets`、`wear/src/main/ets/pages/Index.ets`；新建轻量角色组件和九张双端独立 media 资源、`entry/src/ohosTest/ets/test/CompanionState.test.ets`。

**Interfaces:** `StateSnapshot = { monitoringState, companionState?, bpm?, measuredAt?, isSimulated }`；纯映射 `selectCompanionVisual(snapshot): Resource` 对异常/缺失/过期优先显示监测状态，可信陪伴状态才显示陪伴图。

- [ ] 写失败测试：模拟 BPM、过期样本、未知陪伴状态、断连/停止均不能显示“专注稳定”；六种监测状态及三种陪伴状态映射到不同资源 ID。
- [ ] 运行测试确认失败。
- [ ] 用 `image_gen` 从 `8_Drive/图标和logo` 两张合成图制作并人工核对九张独立素材；保留来源记录，确认手机和圆形手表安全区；不得将整张合成图作为单状态资源。
- [ ] 接入静态组件；随机监测数据显式标模拟，不能凭 BPM 设置陪伴状态；复跑测试并构建双端。

## Task 8：验收与交付（P2）

**Files:** 新建 `docs/FocusAnchor_UX_V2_acceptance.md`；只在发现回归时修改对应功能文件。

- [ ] 按审查框架逐项记录 T01–T12 的状态、测试命令、模拟器/真机型号、截图或日志；明确静态检查、构建、模拟器、真机四级证据。
- [ ] 核对旧入口迁移、九图资源 ID/显示位置、Task/Action/FlashNote 契约、复用与新增接口、卡片接入差异。
- [ ] 执行双端构建及可用的 Hypium 测试；对无法运行的测试写明环境原因，不将编译成功称为跨端闭环。
- [ ] `git diff --check`，审阅仅属于本任务的 diff；列出剩余阻塞及下一阶段建议，不自动开展下一阶段。
