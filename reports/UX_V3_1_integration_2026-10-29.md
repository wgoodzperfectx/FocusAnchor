# UX V3.1 反馈修订与工作树集成

日期：2026-10-29。当前工作目录：`Huang-A/pig-master`，分支 `codex/workflow-v21`，HEAD `81d3a9265369b0481abca661d910434f2fc336ab`。用户允许将 UX worktree 与更新后的工作流代码集成。源工作区仍含多路线未提交改动，因此本轮按文件手工集成，没有执行会覆盖工作树的 Git merge，也未形成提交。

## 用户反馈对应修改

- 删除 Home 顶部 FocusAnchor 品牌栏与头像图标；设置缩为 Home 右上角工具入口。
- 删除“今天，先做一小步”标题、浅绿角色卡和显眼的 Watch status 胶囊；小步伙伴透明图直接占 Home 主屏，文案和唯一主动作跟随角色状态。Step Session 的角色也放大至上半屏主要视觉区。
- 首页不再绘制覆盖内容的悬浮球；Task 页保留文字与语音创建入口，设置、Focus、提醒入口仍可到达。
- 保留监测轻量弹层，由 Home 左上角小状态入口打开；未知连接和模拟数据明确标记。

## 集成范围

从 `10_Codex/worktrees/FocusAnchor-UX-V3.1` 合入 12 个 UX 文件：`Index.ets`、`AppTabs.ets`、`FocusPage.ets`、`StepSessionPage.ets`、`CurrentTaskSelection.ts`、`UiReadModels.ts`、`CompanionView.ets`、`CompanionVisualService.ets`、`color.json`、`main_pages.json`、`ux-current-task-selection.test.mjs`、`UX_V3_1_UI_State_Contract.md`。其中共享页面按 UX 页面目标覆盖，未覆盖更新后的 `AppState`、`WorkflowV21*`、TaskFile、WatchSync、AgentExtAbility、签名或 SDK 文件。

集成后仅在 UI 文件 `StepSessionPage.ets` 接入已存在的 `AppState.proposeWorkflowV21/confirmWorkflowV21`。真实调用开始才显示 LOADING；当前工作流 `WorkflowV21AppService` 使用本地 mock 且设备离线，所以结果标为“本地模拟规划”，不称为 AgentArts 成功。STEP 可编辑并更新计划、接受/拒绝；`LOCAL_CONFIRMED` 后读回任务和 Action 才显示 SAVED。显式本地规则降级保留为次级操作，授权必须为 true。

## 保护与验证

- 集成前源工作区 114 个修改/未跟踪文件与 `10_Codex/backups/pig-master-wip-20261029-085838` 哈希完全一致；备份仍可恢复。逐文件归属见 UX worktree 的 `reports/UX_V3_1_source_ownership_2026-10-29.csv`。
- 合入后 `AppState`、`TaskFileService`、`WatchSyncService`、`WorkflowV21AppService`、`FocusAnchorRouter`、`StorageService`、`AppTypes`、`GuidePage`、`module.json5`、`build-profile.json5` 与备份 SHA-256 仍一致。
- 集成版 `assembleHap`：PASS，ArkTS 重编译。`node --test tests/*.test.mjs`：161/161 PASS。两个原本要求 Task 卡展示多入口的工作流 UI 测试已改为验证 Step Session 的同一业务流程，授权测试改为校验 Step Session 本地规则。新增 `ux-home-state.test.mjs` 的 7 项 fixture 检查和 `ux-step-session-state.test.mjs` 的 7 项 fixture 检查；它们验证状态映射，不代表页面运行交互通过。`git diff --check` 无空白错误。
- DevEco 曾在 UX worktree 预览 `Index` 与 Focus 空态；本次新的整屏 Home 尚无可用的模拟器/真机截图。`hdc list targets` 为空，键盘、安全区、手表同步和跨端 ACK 均未做设备验收。

## 2026-10-29 继续实施记录

- 从 App 根目录执行 `./scripts/verify-workflow-v21.ps1 -EvidenceDirectory D:/70_Competition/FocusAnchor/10_Codex/reports/workflow-v21-local-20261029`：WF 17/17 PASS，更新后全量测试 168/168 PASS。独立 App HAP 构建日志已复制到同一证据目录，脚本报告 `entry=PASS`、`wear=NOT_RUN`；脚本本身不启动模拟器，E2E 设备与真实 provider 项显示 `BLOCKED`。
- 后续 UI 修订：Home 未确认连接的小方块改为中性色；Step Session 将工作流 `AWAITING_CLARIFICATION` 映射为可返回任务补充的 CLARIFY，移除无接口支撑的假提交；错误态的重试可直接重新发起请求或返回未确认建议；Focus 的 UI 读取层预留 LOCAL/PENDING/SYNCED/FAILED/UNKNOWN 五态，未知回执不显示为待同步。
- 本轮仅改 UI 文件 `Index.ets`、`AppTabs.ets`、`StepSessionPage.ets`、`FocusPage.ets`、`UiReadModels.ts`、UI 状态契约文档，以及新增 `tests/ux-flash-sync-state.test.mjs`、`tests/ux-focus-navigation.test.mjs`。底部 Focus 现在直接承载闪念沙盒，独立 `FocusPage` 路由仍保留。FlashNote 持久化模型仍只产出 `pending|synced`，FAILED/LOCAL 需要协同线提供实际状态；澄清回答回传需要工作流接口。本轮没有更改这些数据生产者。
- 新一轮 App HAP 编译 PASS，含 ArkTS 编译；自动化测试 168/168 PASS。新版 Home、Task、Step Session、Focus 尚无手机模拟器/真机交互结果。DevEco 桌面预览控制接口返回 native pipe unavailable；本机只有 `wearable_x86` 系统镜像，`hdc` 返回 `[Empty]`。
- 后续检查发现 Task 完整编辑态仍同时显示顶部快捷输入，已在编辑态收起快捷输入区；创建、语音和提醒功能入口保留。再编译 PASS，自动化测试保持 168/168 PASS。独立 UX worktree 仍保留初版 UI，当前后续修订位于已授权集成的 `codex/workflow-v21` 源工作区；未建立会混入多路线 WIP 的基线提交。
- 将 Home 监测弹层、Task、Step Session、Focus 中原为 36–40 vp 的操作按钮高度调至 44 vp，改善触控目标。App HAP 编译 PASS。新版 Home 的实际 Previewer/模拟器截图仍是验收缺口。
- Home 数据读取失败时，角色文案、视觉状态与主操作同步进入“状态暂不可用 / 查看任务”，不会把缓存任务继续称为当前行动。新增 fixture 覆盖这一错误态；App HAP 编译 PASS，工作流脚本 WF 17/17、全量测试 169/169 PASS。
- Home 图片原设为容器宽 185%，会裁切透明 `status_*` 素材的绿色脚部；根据各状态实际 alpha 边界调整为 108%–125%，使轮廓横向占满角色区域并尽量完整显示。正式九张不透明图片未被自动抠图或覆盖。几何检查与 App HAP 编译 PASS，实际页面截图仍待取得。
- 已完成 Action 从 Task 卡进入 Step Session 时，直接呈现 COMPLETE 与原步骤文本，不再误入“生成第一步”初始态；Task 卡入口统一为“查看这一步”。新增读取态测试；App HAP 编译 PASS，工作流脚本 WF 17/17、全量测试 170/170 PASS。
- Home/Task/Focus/Step Session/底部导航的六种主色（暖浅背景、白色表面、主/次文字、品牌绿、浅品牌绿）已复用 `color.json` 现有 ArkUI 资源；未新增依赖或改动色值。App HAP 编译与全量 170 项测试 PASS，真实渲染对比仍待截图确认。
- Step Session 的任务加载、建议生成、本地规则与保存成功后会清除旧错误；Focus 重新读取或归档成功后也清除过期错误。澄清态文案改为“补充任务信息后，再回来生成第一步”，保留返回任务操作。新增 Focus 刷新态测试，HAP 编译 PASS，全量测试 171/171 PASS。
- Task 输入现按真实日历校验 `YYYY-MM-DD HH:mm`，拒绝无效日期和数字前缀乱码；空标题给出可见提示。编辑对象被其他入口删除时不再显示保存成功，删除失败保留选中态。保存/删除已成功但列表刷新失败时显示独立提示，避免误导重复操作；新增六项输入与回执测试。App HAP 编译 PASS，全量测试 177/177 PASS。
- 手机模拟器阻碍进一步定位：本机 `Pura 90 Pro` 实例配置明确要求 `system-image/HarmonyOS-7.0.0/phone_all_x86/`，但该镜像路径不存在；已安装的 system-image 只有 `wearable_x86`。实例日志在 2026-10-29 08:44/08:45 报 `can not open image_signature file`、`can not read uuid file`，`hdc list targets` 为空。需要通过 DevEco Device Manager 安装匹配手机镜像或连接手机后，才能运行 HAP 取得真实页面截图；现有 Previewer 截图仍属于较早 Focus 页面。
- Step Session 在用户提交“修改计划”并收到新 revision 后保留会话内 `userEdited` 状态，结果区显示“已由你修改”；本地规则建议在草稿文字变化时也显示该标签。跨页面可恢复的来源仍需工作流回执字段，UI 不自行推断已持久化 provenance。新增更新计划状态测试；HAP 编译 PASS，全量 178/178 PASS。

## 当前合并边界

源工作区已包含新版 UX 源码和更新工作流代码，但仍是未提交工作树，不是独立 Git 合并提交。UX worktree 保留供对照。后续建立正式集成提交时，必须逐件审查 Agent/协同/共享配置与未跟踪产物，避免把密钥、临时文件或预览缓存一起提交。
