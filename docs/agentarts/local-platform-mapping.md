# 本地业务与 AgentArts 执行映射

## 2026-11-17 平台映射复核

平台最小草稿已创建，ID `1542f0de-f841-46a0-875d-cfd2d34d2263`，Start 只接收 `query:String`，其中传入经本地授权和最小化后的 JSON 字符串；模型返回 `raw_output:String`，End 的 `result` 引用该字符串。第二次 Trial Run 最终文本包含 `STEP`、原样关联 ID、标题、目标、五个步骤、空的 `question/errorCode`，为 **PASS / E2（预览）**。平台未包含 G0、M1/M2、AppState、同步、知识库、插件、MCP 或个人记忆。

平台草稿字段仍不是本地 `TaskPlan 2.1.0`：没有 `schemaVersion`、`planId`、`planRevision`、`stepId/order/status/estimatedStartMinutes`、`firstStepId`、`plannerProvider/plannerVersion`。`scripts/agentarts-planner-draft.mjs` 只校验预览文本的八字段草稿；新增 `entry/src/main/ets/services/AgentArtsPlannerMapping.ts` 在**本地提供**计划 ID、修订、步骤 ID、预计启动时间与来源后，将 STEP 映射到现有 `TaskPlan` 并执行 `validateTaskPlan`。这条映射用平台预览文本离线回放 **6/6 PASS / E1**。`scripts/agentarts-planner-provider.mjs` 把已由调用方许可的 `query` 传入候选 Runtime 路径，并从假 SSE 的 `outputs.result` 解析草稿：**4/4 PASS / E1**；其输入白名单拒绝原始生理/精确位置字段。平台提示词声明接受 U/C 两种标签，但只对 U 做过 Trial Run；C 的实际平台行为、真实 SSE 键名及正式 API 均未验证。ID 生成策略、CLARIFY/ERROR 的状态机映射和来源标记仍须按 `v2.1-contract-change-proposal.md` 评审；当前 App 仍使用 Mock。当前映射状态：平台生成 U 草稿 **PASS / E2**；纯 STEP 映射及候选后端绑定 **PASS / E1**；正式接入 **BLOCKED**；真实 API **NOT_RUN**。

下方 2026-11-15 的 BLOCKED 描述是账号暂停期间的历史快照，不代表当前平台状态。

## 2026-11-15 历史映射

状态：本地静态审查 **PASS / E0**；平台映射 **BLOCKED**。当前 App 分支 `codex/workflow-v21`，HEAD `81d3a9265369b0481abca661d910434f2fc336ab`。工作树已有大量未提交改动，本轮不覆盖。

| 责任 | 本地证据 | 目标边界 |
|---|---|---|
| 统一事件、U/C 分流、G0 | `entry/src/main/ets/services/WorkflowV21Router.ts:52-107`、`WorkflowV21Validation.ts:9-23` | 保留本地。Channel U 对应代码 `USER`；Channel C 对应 `CONTEXT`。 |
| M1/M2 与决策分支 | `WorkflowV21Router.ts:142-175`、`WorkflowV21Contracts.ts:8-22` | 保留本地 Policy Runtime；`ABSTAIN`/`DEFER` 不触发 AgentArts；`ASK` 先本地澄清。冻结枚举为 `INTERVENE/DEFER/ASK/ABSTAIN`，`SUGGEST` 仅是业务描述。 |
| 任务理解与步骤生成 | `WorkflowV21Router.ts:114-140`、`WorkflowV21Mocks.ts:27-42` | 将 Planner 的生成部分映射为单个 AgentArts 执行 Workflow；调用前已完成本地门控。 |
| TaskPlan 校验 | `WorkflowV21Validation.ts:55-63` | 仍在本地校验真实输出，非法/超时安全失败；平台节点“成功”不等于合法 TaskPlan。 |
| 用户确认、Task/Action 写入 | `WorkflowV21Router.ts:200-233`、`WorkflowV21Mapping.ts` | 保留主体 App 权威控制；AgentArts 不写 AppState。 |
| 交付与回执 | `WorkflowV21Router.ts:235-290`、`WorkflowV21Contracts.ts:29-31` | 保留本地同步适配；AgentArts 不推送卡片或手表。 |
| Intent | `Wang-B-Agent/intent-framework/intent-framework.yaml:8,107-122` | 平台用户意图仅用于明确用户请求；后台事件不是伪造用户意图。当前 AgentArts 注册状态未知。 |
| Skill | `Wang-B-Agent/skills/focusanchor-agent-workflow/SKILL.md:19-31` | 用作 Planner 行为约束参考，不把整份 Skill 当作已发布平台能力。 |
| Knowledge / Plugin / Personal Memory | `Wang-B-Agent/skills/focusanchor-agent-workflow/SKILL.md:73-85` | 本轮不进入最小 Workflow；不更新平台知识库。 |

旧 `Wang-B-Agent/workflows/dual-channel-sgcw/workflow.yaml` / `adapters.yaml` 与 `tests/workflow-acceptance-cases.yaml` 属 `0.1.0` 遗留资产；其 `user_captured_thought`、`card_action` 等字段不符合 V2.1 入口白名单，不能整体导入或直接运行。V2.1 的权威本地校验为 `WorkflowV21Contracts.ts` 与 `WorkflowV21Validation.ts`；`Wang-B-Agent/skills/focusanchor-agent-workflow/references/runtime-contract.md` 解释现状。`current-state.md` 在本工作空间按文件名检索未找到，不能将其视作已读的现状基线。

最小平台设计只需要一个 `FA_TaskPlanner_v0_1`：接受本地筛选后的请求、已有步骤摘要与输出语言，生成可解析的 STEP/CLARIFY/ERROR 候选。平台开始节点字段、输出节点事件及可复用资源须在账号恢复后核对。对 Channel C，只有 G0 和 M2 允许的 `INTERVENE` 才可请求平台生成可拒绝的建议；`ASK` 须先得到用户同意，`ABSTAIN/DEFER` 不调用平台。**生成建议不等于用户接受或 Task 持久化。**现行 Mock 路由在用户接受建议后才调用 Planner，这一时点差异尚未实施目标映射。

候选平台节点顺序（**设计，不是已创建资源**）：Start 接收来源与任务摘要 → LLM/Agent 生成结构化候选 → End 输出单个状态对象。不得添加 G0/M2 决策节点、KB、Plugin、MCP、Personal Memory 或设备推送节点。`STEP/CLARIFY/ERROR` 的 wire 包络、开始节点键名和 End 的 `user_fields` 形态仍待共享契约审批及平台实测。
