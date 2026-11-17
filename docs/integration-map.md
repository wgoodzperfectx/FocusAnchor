# FocusAnchor Task 0 — 集成现状图

日期：2026-10-29（Asia/Shanghai）
审计分支：`codex/modeling-task0`
已提交源码基线：`81d3a9265369b0481abca661d910434f2fc336ab`

## 证据边界

- 本 worktree 从上述提交建立，审计此处源码是可复现的 E0 静态证据。
- `<LOCAL_PROJECT_ROOT>/Huang-A/pig-master` 位于 `codex/workflow-v21`，有大量未提交源码；本文件将其称为“并行工作区观察”，不能作为建模分支已有接口。
- `<LOCAL_PROJECT_ROOT>/10_Codex/worktrees/FocusAnchor-UX-V3.1` 位于 `codex/ux-v3-1` 且有未提交修改；未经负责人查看不得合并。
- 章程规定的是目标职责；v2.0 PDF 的 JSON 是建模接口建议，不能据此声称 App 已接入。

## 基线调用与状态路径

```tex
EntryAbility / pages
  -> AppState.bootstrap
     -> StorageService (preferences/encrypted bundle)
     -> TaskFileService (tasks.json)
     -> WatchSyncService (分布式 KV)
     -> ReminderService (15 分钟周期通知)
  -> FocusPage -> XiaoyiBridge.startHeartRateStream
     -> HeartRateService.start (Math.random 模拟 BPM)
     -> AppState.applyBpm -> HeartRateSnapsho
  -> AppTabs 用户点击 -> XiaoyiBridge.askAdvice (本地 fallback)
```

| 领域 | 已核实的文件与符号 | Task 0 结论 |
|---|---|---|
| Task | `entry/src/main/ets/models/AppTypes.ets` 的 `StudyTask`；`services/AppState.ets` 的 `tasks/bootstrap`；`services/TaskFileService.ets` 的 `loadTasks/saveTasks` | 本地任务源存在；Task/Action 事务不在本轮改动范围。 |
| Focus/心率 | `pages/FocusPage.ets` 的 `aboutToAppear/applyBpm`；`services/XiaoyiBridge.ets` 的 `startHeartRateStream`；`services/DomainServices.ets` 的 `HeartRateService.start` | `Math.random` 每 2 秒生成 BPM；`focusLevelFromBpm` 是规则映射。无真实生理推断证据。 |
| Reminder | `services/ReminderService.ets` 的 `startPeriodicCheck/notifyIncomplete`；`AppState.bootstrap` 启动检查 | 按未完成任务数量定时通知；不是 M2 策略或 G0。与未来主动策略有潜在触达冲突，应先单独设计整合。 |
| Agent | `services/XiaoyiBridge.ets` 的 `askAdvice/localAdviceFallback`；`pages/AppTabs.ets` 的 `requestAdvice` | 当前可见建议路径是本地 fallback，不可称作真实 Agent 推理成功。 |
| 保存/同步 | `services/StorageService.ets` 的 `loadBundle/saveBundle`；`services/WatchSyncService.ets` 的 `pullIfNewer/pushTasksToWatch` | 有存储和分布式同步代码；未做跨端设备验证。 |
| 许可/门控 | 基线 `AppTypes.ets` 的 `PrivacySettings` 只有通用隐私字段；未找到 M1/M2/G0 类型 | 基线没有可用的主动建议许可与确定性门控。不可用模型分数填补。 |
| 网络 | `entry/src/main/module.json5` 含 `ohos.permission.INTERNET`；`wear/src/main/module.json5` 未见 INTERNET；基线 ETS 搜索未见 HTTP client/NetworkKit 调用 | 手机声明网络权限不等于已有 FastAPI 接口、可达服务或安全传输；具体网络方案与服务地址待 Task 6–7。 |

## 并行工作区观察（未提交，不能直接依赖）

`Huang-A/pig-master/entry/src/main/ets/services/WorkflowV21Contracts.ts` 定义 `ContextFeatures`、`InterventionDecision`、`WorkflowDeps.estimator/policy`，版本为 `2.1.0`；决策枚举是 `INTERVENE/DEFER/ASK/ABSTAIN`。`WorkflowV21Mocks.ts` 提供 Mock estimator/policy。`WorkflowV21AppService.ets` 明确以本地 Mock 运行，设备设为 offline。`FocusConsent.ts` 定义 `resolveFocusConsent`。这些说明存在可讨论的接缝，但仍需共享契约审批与合并。

v2.0 PDF 的示例 `StateEstimate`/`InterventionDecision` 版本为 `1.0`，动作含 `suggest`，字段名也不同。建模服务不能直接把 PDF 示例 JSON 作为 `WorkflowV21Contracts.ts` 的运行时响应；需提出版本映射、字段来源、缺失值、校准状态和失败路径的兼容提案。

## 建议集成方向及依赖

1. Task 1–5 在建模 worktree 的独立 Python 目录开展；输入仅取已登记且许可核实的数据，输出模型证据与候选决策，不连接 Agent。
2. Task 6 可在模型与四类 schema 经过验证后提供只读预测/回放 API。请求中必须标明 replay 来源，响应带质量、不确定性、模型版本与拒判原因。
3. Task 7 前先批准共享契约和网络/许可方案；端侧 `DecisionEngine` 对 DND、主动许可、冷却、活动排除、信号质量、OOD、不确定性、近期拒绝执行确定性否决。模型不能绕过。
4. 接入 `WorkflowV21*`、`AppState` 或 `ReminderService` 是跨路线变更，先提交影响矩阵并由负责人决定合并顺序。工作流部署当前冻结。

## 文件级影响与接口缺口

本轮只新增 `AGENTS.md`、`docs/architecture/FocusAnchor_Architecture_Charter_v0.1.md`、`docs/integration-map.md`、`docs/modeling-boundaries.md`、`docs/task0-file-inventory.md`。无业务源码、权限、签名或生产配置修改。

| 需求 | 当前接口 | 缺口 | 后续验收 |
|---|---|---|---|
| M1 状态证据 | 基线 `HeartRateSnapshot` 仅 BPM/zone/focusLevel | 无来源、质量、校准、uncertainty/OOD、时序特征 | Task 2–4 产出 schema、LOSO 与校准证据。 |
| M2 候选决策 | 基线无 M2；并行工作区有 Mock `policy.decide` | 未批准的跨版本映射，缺少真实 receptivity 模型 | Task 5 后验证候选格式及拒判。 |
| 确定性门控 | 基线无主动建议 G0；并行工作区有部分门控逻辑 | 主动许可、DND、cooldown 等端侧统一执行点未冻结 | Task 7 逐条安全用例、共享审查。 |
| 端侧网络 | 手机 INTERNET 声明 | 无已验证 HTTP client、服务 URL、超时/降级协议 | Task 6–7 服务与端侧联调。 |
| 数据回放 | 无 | 公共数据重放与真实采集的来源隔离 | Task 6 fixture replay，日志不得称真机。 |

## Task 0 验收

状态：**PASS（静态审计 E0）**。真实源码、许可/门控、网络和接口缺口已记录。编译、自动化测试、模拟器与真机均 **NOT_RUN**；因此不证明运行集成。下一阶段先执行数据注册与许可核实，并处理共享契约版本差异。
