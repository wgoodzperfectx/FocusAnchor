# Local Policy × AgentArts 协同验证报告

## 2026-11-17 增量验证

环境：Windows / PowerShell，Node `v24.13.0`；App 工作树 `codex/workflow-v21`，HEAD `81d3a92`。既有大量未提交/未跟踪文件保留，本轮没有 reset、clean、stash、提交或合并。

AgentArts 草稿 `FA_TaskPlanner_v0_1` 已在控制台完成两次合成任务 Trial Run，第二次最终输出为严格 JSON，步骤草稿与请求关联 ID 匹配：**PASS / E2（平台预览）**。首次运行节点均 Success，但 End `responseContent` 是单引号对象字符串，严格 JSON 校验失败；改为模型 Text 输出后第二次 Success，最终文本为双引号 JSON。两次运行时间分别为 26.42s、24.90s。预览没有提供可记录的真实 API Request ID、Session ID、Runtime Name 或 SSE 流。

新增后端专用 `scripts/agentarts-planner-draft.mjs` 和 `tests/agentarts-planner-draft.test.mjs`，用第二次预览的最终文本验证八字段、关联 ID、STEP/CLARIFY/ERROR 边界，并拒绝首次错误格式、额外执行/送达声明与空步骤：**4/4 PASS / E1**。新增纯转换 `AgentArtsPlannerMapping.ts` 和 6 项测试：由本地提供 ID、修订和来源，将观察到的 STEP 映射成现有 `TaskPlan`，再通过本地 G0、确认、拒绝/接受、ABSTAIN/DEFER/ASK 与错误路径做**离线回放**：**6/6 PASS / E1**。`scripts/agentarts-planner-provider.mjs` 将已获本地许可的 `query` 作为 Start 输入，经过假 Runtime SSE 后读取 End `outputs.result` 并校验预览草稿；输入白名单在网络前拒绝原始生理/精确位置字段，缺失输出、伪造关联 ID、非法 JSON 均失败关闭：**4/4 PASS / E1**，日志 `evidence/agentarts-planner-provider-2026-11-17.tap`。该适配函数不执行 G0，也未经真实 API 验证。全量自动化复跑：**201/201 PASS / E1**，命令 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/*.test.mjs`，日志 `evidence/app-all-2026-11-17.tap`。WF-01～17 均包含在全量运行中，仍是本地 Mock 证据。

| 集成层 | 当前状态 | 原因 |
|---|---|---|
| Local Policy 的 G0、ABSTAIN、DEFER、ASK 与确认状态机 | PASS / E1（Mock） | 现有测试；本轮未改已通过的状态机。 |
| AgentArts 平台草稿生成 | PASS / E2（预览） | 两次合成 Trial Run，第二次严格 JSON 草稿。 |
| 草稿文本校验 | PASS / E1 | 后端边界能消费观察到的最终文本；该模块只校验八字段草稿。 |
| STEP 到现有 TaskPlan 的纯映射 | PASS / E1（回放） | 本地提供业务身份；`validateTaskPlan` 通过，拒绝模型伪造 ID、额外执行声明。未接正式 Provider。 |
| Start `query` → End `result` 的候选后端绑定 | PASS / E1（假 SSE） | 以真实预览文本和模拟 Runtime 包络测试本地消费链；U/C 输入标签和字段白名单经本地测试，只有 U 经平台 Trial Run，C 的平台行为与真实 API 输出键、鉴权、调用路径仍未核实。 |
| 真实 AgentArts API 与 SSE 包络 | NOT_RUN | 账号持有人已订阅所选 `GLM 5.2-ArkTS-SPARK`（控制台 E2，只读复核）；草稿仍未发布、无 Runtime Name/访问域名、受控后端鉴权和费用上限，真实调用仍无证据。 |
| App 正式调用、手机/手表交付 | NOT_RUN | App 仍注入 Mock；无真机与跨端证据。 |

本轮新增后端草稿校验器、候选绑定、纯映射文件与测试，未改 App 的共享接口、既有 Workflow、状态持久化或设备同步。手机 SDK 顺序构建 **PASS / E1**，命令 `hvigorw.bat assembleHap --mode module -p module=entry@default -p product=default`，日志 `evidence/entry-build-2026-11-17.log`；手表 SDK 构建 **PASS / E1**，同命令将模块改为 `wear@default`，日志 `evidence/wear-build-2026-11-17.log`。手机 ArkTS 编译实际执行，手表 ArkTS 为 up-to-date；新增后端模块未打入 HAP，本轮未重新构建或运行模拟器/真机。

独立日志：`evidence/agentarts-planner-draft-2026-11-17.tap`、`evidence/agentarts-planner-mapping-2026-11-17.tap`、`evidence/workflow-v21-2026-11-17.tap` 与 `evidence/app-all-2026-11-17.tap`。映射命令 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/agentarts-planner-mapping.test.mjs`；WF 专项 **17/17 PASS / E1**，命令 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/workflow-v2.1.test.mjs`。

2026-11-17 补充 Planner 调用计数断言后再次执行：WF-01～17 **17/17 PASS / E1**，日志 `evidence/workflow-v21-gate-counts-2026-11-17.tap`；全量 **201/201 PASS / E1**，日志 `evidence/app-all-gate-counts-2026-11-17.tap`。命令分别为 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/workflow-v2.1.test.mjs` 与 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/*.test.mjs`。本次只修改 Mock 测试断言和报告，未重新编译 SDK、运行模拟器或发起 AgentArts 调用。

同日新增 `tests/agentarts-planner-offline-integration.test.mjs`，在一条本地路由中串接 G0 → 注入式假 `fetch` → 候选 `query/result` 绑定 → 草稿解析 → `TaskPlan` 映射 → 用户确认。三项断言分别验证 USER_REQUEST 在确认前不持久化、G0 与 ABSTAIN/DEFER/ASK 均不触达假传输、无效最终文本安全失败：**3/3 PASS / E1**。专项命令 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/agentarts-planner-offline-integration.test.mjs`，日志 `evidence/agentarts-planner-offline-integration-2026-11-17.tap`；全量同一命令格式运行 `tests/*.test.mjs`：**204/204 PASS / E1**，日志 `evidence/app-all-offline-integration-2026-11-17.tap`。该测试的域名、凭证、SSE 与 `fetch` 均为合成输入，不证明真实 Runtime、后端部署或 App 注入。

### 2026-11-15 历史基线

日期：2026-11-15。运行环境：Windows；App 工作树 `codex/workflow-v21` / `81d3a9265369b0481abca661d910434f2fc336ab`。本轮只执行本地测试与平台只读观察；无 App 源码改动。

| 要求 | 状态 / 等级 | 当前证据与未覆盖范围 |
|---|---|---|
| USER_REQUEST 过 G0 后规划 | PASS / E1（Mock） | `tests/workflow-v2.1.test.mjs` WF-01/02；实际 AgentArts 调用 BLOCKED。 |
| ABSTAIN 不调用生成 Provider | PASS / E1（Mock） | `WorkflowV21Router.ts:158` 在规划前返回；WF-10 直接断言 Planner 0 次、无任务、建议和设备调用。 |
| DEFER 仅本地调度 | PASS / E1（Mock） | WF-09 断言初次和撤销授权后的到期重查均未调用 Planner；真实后台调度未验证。 |
| ASK 受控询问 | PASS / E1（Mock） | WF-11 断言提问和静默后的 Planner 调用均为 0；“用户同意后再调用 AgentArts”的端到端链路 BLOCKED。 |
| INTERVENE 候选建议与确认 | PASS / E1（现行 Mock 路由） | WF-08/16；现行枚举为 `INTERVENE`，不是 `SUGGEST`。WF-08 直接断言建议前 Planner 调用数不增加、用户接受后恰增一次；目标的“G0 后调用 AgentArts 生成建议”尚未实现，真实平台路径 BLOCKED。 |
| 无效输出、异常、超时 | PASS / E1（Mock） | WF-12，覆盖 Planner/M1/M2 注入错误；AgentArts SSE/网络错误尚未测试。 |
| 拒绝、修改不擅自持久化 | PASS / E1（Mock） | WF-03/04；真实 Provider 输出后的确认链路 BLOCKED。 |
| 离线 SSE 终结事件解析 | PASS / E1 | 新增 `AgentArtsSse.ts`，`tests/agentarts-sse.test.mjs` 覆盖成功、错误、等待、截断和非法输出；仅使用人工合成事件。 |
| 受控后端传输边界 | PASS / E1（离线） | `scripts/agentarts-runtime-client.mjs` 以注入的 `fetch` 测试 HTTPS、Runtime 路径、关联 ID、超时、HTTP/网络错误、SSE 终结事件和 1 MiB 响应上限；4/4 合成测试通过。无真实鉴权、平台请求或工作流输出映射。 |
| AgentArts App 注入 | BLOCKED | 现行 App 仅 `createMockRuntime` 且设备 offline（`WorkflowV21AppService.ets:10,25-27`）；后端模块不打包进 HarmonyOS，也未接入 App。 |

执行命令（App 根目录）：

```powershell
node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/workflow-v2.1.test.mjs
node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/agentarts-sse.test.mjs
node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/agentarts-runtime-client.test.mjs
node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/*.test.mjs
```

此前结果：WF-01～17 **17/17 PASS**；SSE 离线解析 **5/5 PASS**；App 全量 **183/183 PASS**，见 `evidence/workflow-v21.tap`、`evidence/agentarts-sse.tap` 与 `evidence/app-all.tap`。本次新增后端传输边界并复跑：传输 **4/4 PASS**、App 全量 **187/187 PASS**，见 `evidence/agentarts-runtime-client.tap`、`evidence/app-all-current.tap`。均为人工合成响应与本地测试，不是平台实测。

SDK 编译：首次 entry 构建因进程内 `DEVECO_SDK_HOME` 未指向有效 SDK 而 **FAIL**（该次诊断仅见命令输出，重跑时日志被覆盖）；按 `local.properties` 设置为 `D:\Tools\DevEco26\DevEco Studio\sdk` 后重跑，entry **PASS / E0**（`evidence/entry-build.log`），wear **PASS / E0**（`evidence/wear-build.log`）。wear 为增量构建，ArkTS 编译任务显示 up-to-date。新解析器未被 App 引用，故构建成功**不证明**其 ArkTS 集成兼容；Node 测试实际执行了该文件。模拟器/真机 **NOT_RUN**。

以上测试仅证明本地 Mock 路由与离线解析，不证明平台预览、真实 API、App 正式调用或设备交付。下一实现前须批准 `FirstStepResult`/来源标记的共享契约映射；不能以旧平台结果或 YAML 声明替代。
