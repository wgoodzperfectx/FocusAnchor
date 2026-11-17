# AgentArts 集成阻塞清单

## 2026-11-17 当前清单

账号已恢复，资源盘点和唯一草稿 `FA_TaskPlanner_v0_1` 的两次合成 Trial Run 已完成；不再将“账号暂停”列为当前阻塞。平台预览第二次 **PASS / E2**，本地草稿校验 **4/4 PASS / E1**，纯 STEP 映射与本地回放 **6/6 PASS / E1**，候选后端绑定假 SSE **4/4 PASS / E1**，本地路由到假传输的离线联接 **3/3 PASS / E1**，最新全量测试 **204/204 PASS / E1**。以下项目仍未完成：

| 优先级 | 项目 | 状态 | 所需证据或动作 |
|---|---|---|---|
| P0 | 共享 Provider / FirstStepResult 契约审批 | BLOCKED | 纯 STEP 映射已能消费预览草稿，但 ID 生成、版本、真实来源及 CLARIFY/ERROR 状态映射待评审 `Wang-B-Agent/design/workflow-v2.1/v2.1-contract-change-proposal.md`；当前未改共享类型。 |
| P0 | 正式 API 的可调用版本与计费 | BLOCKED（模型订阅已解除） | 平台草稿未提交版本。2026-11-17 账号持有人将 `GLM 5.2-ArkTS-SPARK` 与 `GLM-5.2` 设为 `Subscribed`；本代理在 AgentArts 模型授权页只读复核，E2。所选 SPARK 为 `token-based billing`，控制台单价为缓存输入 ¥2.4、普通输入 ¥9.6、输出 ¥33.6／百万 Token；[官方价格表](https://support.huaweicloud.com/price-maas/price-maas-0002.html)一致。免费试用 Tokens 不适用于正式 API，见[官方说明](https://support.huaweicloud.com/lowcode-agentarts/agentarts_05_0186.html)。仍缺 AgentArts Workflow 的 Runtime Name、访问域名、发布状态、受控后端鉴权及费用上限；本代理两次试运行上限已用满，未追加调用或提交版本。 |
| P1 | 真实 Runtime API 与 SSE 输出 | NOT_RUN | 候选 `query` → `outputs.result` 绑定只经假 SSE 验证。前置条件明确后，以受控后端和合成任务取得脱敏 Request ID、Session ID、HTTP/SSE、耗时、终结输出及错误；确认真实输出键名。两次本代理试运行上限已用满，本轮不再发模型请求。 |
| P1 | 本地 Policy × AgentArts 目标时点 | BLOCKED | 当前 `WorkflowV21Router.ts:158-197` 对 INTERVENE 先给本地建议，接受后才调 Planner；目标想在 G0/M2 允许后调用平台生成候选。此状态机/确认时点需单独评审和相应 E2E 回归，不能因预览 Success 改写。 |
| P1 | App 正式 Provider 注入 | NOT_RUN | 当前 `WorkflowV21AppService.ets` 仍是 Mock；后端脚本未部署，也不能进入 HarmonyOS 包。需要可信后端、正式 API 输出、协议映射和 App 端到端验证。 |
| 后续 | Knowledge Base V2 | NOT_RUN | 按本轮明确要求暂缓；不修改 32 条本地资产审批状态，不绑定平台草稿。 |
| 后续 | 手机/手表真实交付 | NOT_RUN | 单独验证持久化、手表收到与 ACK、离线恢复。平台 Trial Run 不证明设备交付。 |

`current-state.md` 在当前工作空间仍按文件名未找到。下方 2026-11-15 清单是账号暂停期间的历史快照，不代表当前状态。

## 2026-11-15 历史阻塞快照

日期：2026-11-15。此清单保留未完成目标，不把文档完成视为平台接通。

| 优先级 | 项目 | 状态 | 解除条件 |
|---|---|---|---|
| P0 | AgentArts 账号暂停 | BLOCKED | 账号持有人按平台流程恢复访问；再只读核对账号、区域、项目和工作空间。 |
| P0 | 已有资源与等价性 | BLOCKED | 读取“我的 Agent/Workflow”、版本、部署与调用路径；先复用，避免重复创建。 |
| P0 | 费用与额度 | BLOCKED | 核对模型、Token 额度、API/调试/发布费用及调用上限；无明确费用条件不调用。 |
| P0 | Provider 共享语义 | BLOCKED | 审批 `v2.1-contract-change-proposal.md` 中 `FirstStepResult`、来源标记、关联字段与旧版兼容方案。 |
| P1 | 最小 AgentArts Workflow | BLOCKED | 完成资源盘点后复用或最多新增一个 `FA_TaskPlanner_v0_1`；不绑定 KB/Plugin/MCP/Memory。 |
| P1 | 真实 API + Adapter | BLOCKED | 离线 SSE 解析和受控后端传输边界已用假 `fetch` 测试；仍须获取实际 Runtime Name、访问域名、发布状态和受控服务端鉴权，脱敏合成任务实测 SSE 与 Schema 后再接 App。后端模块没有部署或接入 App。 |
| P1 | Local Policy × AgentArts E2E | BLOCKED | 目标要求 `INTERVENE` 经 G0/授权后可调用 AgentArts 生成候选；当前 Mock 是用户接受后才调 Planner。先审批调用时点与 `FirstStepResult` 映射，再对 U、ABSTAIN、DEFER、ASK、INTERVENE、错误/超时、拒绝/修改逐项记录真实 Provider 调用计数及本地状态断言。 |
| 后续 | Knowledge Base V2 | DEFERRED | 用户明确要求本轮暂缓；不更新、不审批、不绑定平台 Workflow。 |
| 后续 | 手机/手表真实交付 | NOT_RUN | 单独进行设备、ACK、持久化和离线恢复验收；AgentArts 成功不替代。 |

`current-state.md` 在当前工作空间按文件名未找到，现状依据为真实 Git 状态和源码。现有 `Wang-B-Agent` 资产目录不在本 App Git 仓库内，不能用 App commit 证明其版本。未对既有工作树执行 reset、clean、stash、提交或发布。

2026-11-15 再次只读查看 AgentArts 控制台，仍显示账号暂停，资源与额度无法核查。本地新增 `scripts/agentarts-runtime-client.mjs` 和 4 项离线传输测试；App 全量 187/187 PASS。手机模拟器 `127.0.0.1:5555` 当前连接，设备类型为 phone/emulator；没有手表目标或本轮模拟器 App 运行证据。以上变化不解除真实平台与跨端阻塞。
