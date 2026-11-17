# FocusAnchor UX V2 增量兼容设计

日期：2026-10-14。依据：[UX V2 审查框架](../../FocusAnchor_UX_V2_review_framework.md)及[源码审查记录](../../FocusAnchor_UX_V2_review_findings.md)。本文件定义目标行为；现有代码、构建与双端能力的验证状态仍以验收记录为准。

## 1. 意图与范围

用户从 Home 看到当前任务及真实第一小步，在 Task 显式请求拆分，在 Focus 开始或继续该步并管理手表闪念。主体 App 的任务文件是持久化业务状态源。已接入的 Form Kit 卡片是该状态的投影；手表保留离线输入和反馈能力，经现有 distributedKVStore 汇入主体。复用现有设置、提醒、悬浮球、语音和账户入口。不改 bundle、签名及 SDK 配置，不合并 `Zeng-C` 独立元服务工程。

## 2. 方案选择

选用**在现有 StudyTask / AppState / TaskFileService / WatchSyncService 上增量扩展**。已有卡片已从任务文件取数并回写，但当前 `focusStep` 缺稳定身份与版本。先完善契约、迁移和事件处理，再调整 UI，能保留现有 CRUD、Agent 门控及卡片接入。

另两个方案暂不采用：独立新建任务数据库会形成第二状态源；让卡片与手表继续整包改任务会保留过期反馈覆盖问题。

## 3. 数据与迁移

### Task 与 Action

`StudyTask` 保留已有 ID、标题、内容、优先级、截止时间、完成状态和现有文件存储。现有 `focusStep` 作为当前 Action 的兼容载体，补齐 `actionId`、`taskId`、`order`、`revision`、`generationSource`，延续 `text/status/updatedAt`。公开交互状态为 `ready/in_progress/completed`；暂停属于会话，旧 `paused` 步骤在读取时归一为 `in_progress` 且会话为 `PAUSED`。来源明确区分 `agent/rule/manual/legacy`；现有 `proposeFirstStep()` 属 `rule`，不得标称为在线 Agent 生成。需要“换一步”时，若没有真实候选步骤，返回待拆分状态供 Task 页显式请求；不得将当前步骤标为完成或生成占位内容。新步骤使用新 actionId 和递增 order，旧事件因此不能作用于新步骤。

旧任务读取时若 `focusStep` 缺新字段，以 task ID 与现有 `updatedAt` 生成确定性的旧 Action ID，来源标记 `legacy`，初始 revision 为 1。迁移后的对象先持久化，才供卡片和手表显示。任务不存在或已完成时不生成虚构步骤；任何系统故障不能生成固定占位 Action。

### Focus 会话与闪念

`FocusSession` 独立保存 `sessionId/taskId/actionId/status/updatedAt`，状态为 `IDLE/RUNNING/PAUSED`。开始、暂停、继续不改变步骤完成状态；完成步骤也不自动创建下一步。

`FlashNote` 独立于 Task，含 `flashId/content/sourceDevice/createdAt/syncStatus/convertedTaskId?`。手表先本地持久化并显示“已保存，待同步”，再经既有 KV store 的独立闪念键同步。手机按 flashId 去重并持久化收件箱；用户在 Focus 显式转换为任务时，使用由 flashId 确定的 taskId，先查任务是否已存在，再写任务和闪念关联。即使在两次写入之间中断，重试也不会创建第二个任务。删除采用收件箱归档/墓碑记录，防止离线重放后复活。收件箱到达不改变当前 Task、Action 或页面。Agent 当前手机本地 `ThoughtRecord` 可读取作既有记录，但不可假作手表闪念。

### 事件与冲突

跨端步骤操作携带 `eventId/taskId/actionId/baseRevision/type/origin/createdAt`。主体先核对任务和 Action 身份，再检查版本与允许的状态转移；已处理 eventId 持久化去重并返回原结果，旧 Action 或冲突版本返回当前状态供端侧刷新。先写任务文件，再刷新卡片及同步手表。手表离线操作持久化为待发送事件，收到主体确认后才标记已同步；不再以手表整包任务作为 Action 反馈的唯一依据。保留现有 `updatedAt` 供旧数据兼容及任务列表合并，但同一步操作以 actionId + revision 判定。已有手表任务编辑入口在迁移期间不直接覆盖手机 Action；任务变更也须转为主体可核验的请求，直到该链路接通才恢复相应编辑操作。

## 4. 页面与跨端流程

- **Home**：顶栏保留设置入口；主视觉、监测摘要、任务与真实第一步、单个开始/继续操作。无任务跳 Task 创建；有任务无步骤跳 Task 请求拆分。Guide 不再作为主导航。保留悬浮球、语音与提醒能力，提醒移至已有次级入口。
- **Task**：沿用 CRUD、优先级和 Deadline。文字与语音填入同一编辑流程。选中任务后“帮我拆成第一步”尝试调用可从 UI 使用、且受同意和安全门控约束的 Agent 接口。若当前工程没有这样的可调用接口，不声称 Agent 已运行；仅可提供明确标识的 `proposeFirstStep()`“规则建议”，用户确认后持久化。不可用、拒绝或空结果显示明确状态。已有有效 Action 不被一次点击覆盖。
- **Focus**：显示任务、Action 和 FocusSession 的开始/暂停/继续/完成状态；现有视觉与计时能力先核对再复用。闪念收件箱默认折叠，支持查看、显式转 Task 与删除。删除和转换保留可追踪状态。新闪念只更新列表。
- **卡片**：沿用当前 FormAbility、卡片页面和刷新服务。绑定数据加入 actionId/revision；按钮事件带 eventId，并交给主体统一操作逻辑。空状态只引导打开 App。卡片不可仅修改自己的 Preferences 即宣称任务完成。
- **手表**：任务区域显示当前 Action，并提供完成、换一步、暂停；换一步发请求而不完成当前步。闪念复用可用的快捷/文字入口；语音和物理键能力须设备验证后才能作为正式入口。保留本地任务缓存，但旧数据与同步失败必须标明。

## 5. 监测、陪伴与图片

`MonitoringState` 为 `CONNECTING/READING/MONITORING/SIGNAL_UNSTABLE/RECONNECTING/STOPPED`；`CompanionState` 为 `STABLE/FLUCTUATING/SUPPORT_REQUESTED/UNKNOWN`。状态快照另含 BPM、样本时间和 `isSimulated`。技术异常、缺失或过期优先显示监测图；正常且有可信陪伴信号时显示陪伴图；否则显示中性“持续监测”。目前随机 BPM 只能标记模拟，不据其推断陪伴状态。

`8_Drive/图标和logo` 的六态图和三态图是合成源图。需得到九个独立资源并检查视觉裁切、安全区及资源 ID 后，手机和手表才可按状态映射。旧 `status_*.png` 是 Guide 流程图，不复用为监测/陪伴状态。先做静态切换，不新增动效框架。

## 6. 错误处理与验证

加载失败保留可辨识的旧数据提示；同步失败保留待发送事件，不显示“已同步”；Agent 失败不产生 Action；无有效监测数据不显示可信心率结论。构建和测试分别记录；T01–T12 用自动化覆盖纯状态/迁移/幂等逻辑，页面、卡片、手表以及断连恢复在模拟器或真机可用时逐项验证。未取得设备证据的项保持“已实现未验证”或“未实现”，不因构建成功改写为通过。

## 7. 实施顺序

P0：迁移与统一 Action/FlashNote/事件处理 → 卡片及手表适配 → Home/Task/Focus 闭环。P1：独立九态资源、状态来源和双端渲染。P2：T01–T12 验收、回归与必要布局修正。每阶段保留当前未提交卡片成果；只改目标工程的相关文件。
