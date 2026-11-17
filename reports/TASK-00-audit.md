# TASK-00 仓库审计（2026-10-25）

## 范围与判定

- **PASS**：仅审计 `Huang-A/pig-master` 的现状并记录最小接入方案；未改业务代码、Agent 意图、UI、权限或发布配置。
- **PASS**：已读取 `10_Codex/FocusAnchor_Physio_Codex_Tasks_v1/focusanchor_codex_bundle/` 全部 10 份文档。`D:\AGENTS.md` 要求中文回复。
- **FAIL（资料缺口）**：工作区 `D:\70_Competition\FocusAnchor` 与实际 Git 根 `Huang-A/pig-master` 均无 `AGENTS.md`、`current-state.md`；不能声称已读取不存在的文件。本报告末尾给出 current-state 增量建议。
- **NOT RUN**：当前轮未执行 DevEco/HAP 构建、模拟器或真机测试；历史构建记录见 `docs/FocusAnchor_UX_V2_acceptance.md:5-14`，不能代替本轮验证。

## 1. 实际仓库状态

实际 Git 根为 `D:\70_Competition\FocusAnchor\Huang-A\pig-master`，当前提交 `81d3a92`（2026-07-17）。外层 `D:\70_Competition\FocusAnchor\.git` 不是有效 Git 仓库；从外层直接运行 `git status` 被上级 `D:\.git` 捕获，输出整盘未跟踪项。所有 Git 命令须显式使用内层根。

`build-profile.json5` 声明 `entry` 和 `wear` 两模块、SDK 26.0.0；`entry/src/main/module.json5:4-13` 为 phone/tablet，`wear/src/main/module.json5:4-13` 为 wearable。仓库已有大量预存的暂存、修改和未跟踪文件；不能将它们归于本审计，也不能重置。`ml/`、`reports/`（审计前）及 `docs/current-state.md` 不存在。

## 2. 已有功能与调用关系

| 项目 | 证据与状态 |
| --- | --- |
| 入口/状态 | `entry/src/main/ets/entryability/EntryAbility.ets:14-31` 在载入 `pages/Index` 前调用 `AppState.bootstrap`；`entry/src/main/ets/services/AppState.ets:69-111` 初始化本地存储、任务、分布式 KV、卡片、手表事件监听、周期提醒。**PASS（静态）** |
| 任务所有权 | `TaskFileService.ets:8,22-36,41-87` 使用 `context.filesDir/tasks.json` 并串行化写入；`AppState.ets:81-91` 从任务文件读取，旧 bundle 为回退；`AppState.ets:191-253` 管理确认的小步。**PASS（静态）** |
| 跨端 | `WatchSyncService.ets:7-13,40-64,66-127,129-207` 在手机侧用 `focux_watch_sync` KV 推送任务投影、消费 watch Action/FlashNote 并确认；`wear/src/main/ets/pages/Index.ets:320-349,384-425,439-503,619-657` 读取投影和排队事件。**PASS（静态）**；设备连通性 **NOT RUN**。 |
| Agent 与门控 | `entry/src/main/module.json5:90-100` 声明 Agent 扩展；`FocusAnchorAgentExtAbility.ets:24-45` 接收文本并调用 `loadFocusRuntime`、`routeFocusAnchor`；`FocusAnchorRuntime.ets:16-25` 读取当前任务与隐私设置；`FocusAnchorRouter.ets:8-18,21-55` 有首步授权、危机/医疗关键词和本地路由；`AppTabs.ets:394-415` 与 `GuidePage.ets:210-250` 要求用户确认首步。**PASS（静态）**，不等于生理介入门控已具备。 |
| 模拟健康状态 | `DomainServices.ets:12-63` 每 2 秒随机漂移 BPM 并标 `isSimulated: true`；`XiaoyiBridge.ets:42-62,288-310` 心率、建议走本地模拟/文案；`FocusPage.ets:46-64` 消费该流。`CompanionLogic.ts:14-40` 排斥模拟/过期样本作为可信稳定状态。**PASS（静态）**。WESAD 状态回放 **NOT RUN**。 |
| 提醒 | `ReminderService.ets:25-67` 每 15 分钟对未完成任务发通知，含手动提醒。现有实现未发现勿扰、冷却或生理信号触发策略；**FAIL（未来策略前置能力缺失）**。 |
| 自动化 | `tests/*.test.mjs` 共 7 个文件，覆盖 Action/会话/同步/闪念/伴随状态；本轮 `node --test tests/*.test.mjs` **PASS：29/29**（Node v24.13.0）。无 `entry/src/test`、`wear/src/test`；设备交互 **NOT RUN**。 |

## 3. 权限、网络与不确定项

- `entry/src/main/module.json5:14-54` 已声明 `INTERNET`、`DISTRIBUTED_DATASYNC`、麦克风等；`wear/src/main/module.json5:13-26` 只声明分布式同步。静态搜索未发现 Health Kit 权限或现有 HTTP 客户端。当前轮未改权限。真机上 `127.0.0.1` 指手机自身，Python 服务若在 PC 运行需可达的受控 LAN 地址；路由、HTTP 明文策略、设备连接均 **NOT RUN**，不能凭 `INTERNET` 声明判定可通。
- `AppTypes.ets:125-134,162-182` 定义 `consentFocusSupport`，但默认值为 `true`；`StorageService.ets:96-114` 合并隐私设置时丢弃两项 consent 字段；`SettingsPage.ets:91-109` 保存设置时也未带入这两项，且没有对应 UI。`FocusAnchorRuntime.ets:22-23` 以 `!== false` 判授权。对新生理主动提示而言，**FAIL：缺少明确、可持久化且可撤回的 opt-in**；TASK-03 前必须解决，不能直接复用当前默认值。
- 现有 `HeartRateSnapshot` 是 BPM/区间（`AppTypes.ets:115-124`），与 bundle `CONTRACTS.md` 的 `StateEstimate` 不同；不能把 WESAD BVP 预测填入 BPM，也不应调用 `AppState.applyBpm`。现有 Agent 扩展是文本入口，`XiaoyiBridge.askAdvice` 目前返回本地文案；真实小艺执行、E3 真机闭环均 **NOT RUN**。
- 没有发现现成 `doNotDisturb`、`reminderCooldownActive`、`allowProactivePrompt` 或 `userPaused` 的完整策略状态。`FocusSession` 有 PAUSED，但仅代表当前 Action 会话；Agent `companionPaused` 是另一状态，不可推定为全局勿扰。需明确语义与持久化位置。

## 4. 精确到文件的最小后续变更计划（均未执行）

### TASK-01：只在新目录落地 Python 实验

新增 `ml/pyproject.toml`、`ml/configs/baseline.yaml`、`ml/src/focus_physio/data/wesad.py`、`ml/src/focus_physio/data/windows.py`、`ml/src/focus_physio/features/extract.py`、`ml/src/focus_physio/models/train.py`、`ml/src/focus_physio/models/evaluate.py`、`ml/tests/`、`ml/README.md`；扩充仓库根 `.gitignore`，仅忽略 `ml/data/raw/WESAD/`、`ml/artifacts/`、`ml/reports/` 等数据与工件。TASK-01 不需要修改任何 ArkTS 文件。

### TASK-02/03：以状态估计旁路接入

新增 Python `ml/src/focus_physio/inference/predict.py`、`replay/session.py`、`api/app.py`（最终命名以 TASK-02 契约为准）。ArkTS 新增 `entry/src/main/ets/models/PhysioTypes.ts`、`entry/src/main/ets/services/PhysioAdapter.ets`、`ReplayAdapter.ets`、`PhysioStateService.ets`、`InterventionPolicy.ts`，只传 `StateEstimate`。接入点优先考虑 `AppState.ets` 的 bootstrap 生命周期和只读任务上下文；界面确认由 `entry/src/main/ets/pages/AppTabs.ets` 或 `GuidePage.ets` 的现有确认流程承接，需在 TASK-03 确定一个明确入口。`TaskFileService.ets`、`WatchSyncService.ets`、Agent 意图文件保持原所有权，不能复制任务库或绕开 `FocusAnchorRouter.ets:8-55` 门控。

TASK-03 若新增主动提示，需定点修改 `AppTypes.ets`（独立生理授权/策略状态）、`StorageService.ets`（保留 consent 字段并默认拒绝新授权）、`SettingsPage.ets`（显示及撤回）、`AppState.ets`（生命周期与只读上下文）、选定确认页，并新增策略测试。`entry/src/main/module.json5` 本轮无需变更；任何额外网络或 Health Kit 权限另行论证。以上是拟议文件，不是已完成实现。

## 5. 风险、阻塞与 TASK-01 先决条件

1. **阻塞 TASK-01**：操作者须确认官方 WESAD README、许可/非商业条件，并将可信原始文件自行放到 `ml/data/raw/WESAD/`；本轮没有读取或下载任何 pickle。数字标签、必需键及尺寸必须以官方 README 和实际数据核对，不能猜测。
2. **阻塞集成**：当前工作树很脏且含已暂存内容；后续变更需先记下基线并限定文件范围。缺少明确生理 opt-in、勿扰、冷却及拒绝/撤回状态；不应把随机 BPM 或旧 consent 当成新策略授权。
3. **环境风险**：历史 DevEco 构建成功记录与本轮实时状态不同；当前 `hvigor` 不在 PATH。当前无真机网络和跨端验证证据。Python API 若服务于真机必须确定可信 LAN、超时和故障降级；不提交个人 IP。
4. **数据/模型风险**：WESAD 多频率腕部信号须独立时间轴、按受试者 LOSO、只在训练折拟合预处理；不能把 public stress 当注意力、干预需求或医疗诊断。详见 bundle `ARCHITECTURE.md`、`EXPERIMENT_PROTOCOL.md`。

TASK-01 可开始的检查表：官方 README/许可已归档；操作者已放置可信数据并确认来源；`.gitignore` 规则先建立且检查数据未被跟踪；确认 Python 环境与依赖锁定方案；保留本审计时的 Git 基线；约定仅修改 `ml/` 与必要的 `.gitignore`。未满足时应清晰报缺数据，不生成虚假指标。

## 6. current-state 建议与复核命令

若后续创建 `docs/current-state.md`，建议新增“2026-10-25 / TASK-00”条目：真实根为 `Huang-A/pig-master`；手机/手表模块与所有权如上；心率仍为模拟；Node 29/29 PASS；DevEco/真机本轮 NOT RUN；生理授权/策略未具备；WESAD 数据许可和来源待确认。当前没有历史 `current-state.md` 可供增量编辑，故未创建该文件。

从 `D:\70_Competition\FocusAnchor\Huang-A\pig-master` 运行：

```powershell
git rev-parse --show-toplevel
git status --short
rg --files -uu entry/src/main wear/src/main tests docs -g '!**/build/**' -g '!**/.git/**' -g '!**/media/**'
rg -n 'consentFocusSupport|doNotDisturb|cooldown|allowProactivePrompt|userPaused' entry/src/main/ets wear/src/main/ets -g '*.ets' -g '*.ts'
rg -n 'INTERNET|DISTRIBUTED_DATASYNC|Health|http|localhost' entry/src/main wear/src/main -g '*.ets' -g '*.json5'
node --test tests/*.test.mjs
git diff --check
```

`git diff --check` 本轮退出码 0，仅有已有文件 LF/CRLF 警告。构建参考命令见 `docs/FocusAnchor_UX_V2_acceptance.md:8-10`，本轮 **NOT RUN**。

DevEco 构建入口在本机 `D:\Tools\DevEco26\DevEco Studio\tools\hvigor\bin\hvigorw.bat`，历史记录使用的参数可分别用于 `entry` 与 `wear`：`assembleHap --mode module -p module=entry@default -p product=default`、`assembleHap --mode module -p module=wear@default -p product=default`。当前轮未调用该程序，也未启动 `Run`、模拟器或真机；实际 SDK、签名及可运行性仍须复测。
