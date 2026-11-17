# AgentArts 真实调用测试记录

## 2026-11-16 平台 Trial Run；2026-11-17 本地复核

测试资源：`FA_TaskPlanner_v0_1`，Workflow ID `1542f0de-f841-46a0-875d-cfd2d34d2263`，区域 `cn-southwest-2`，状态 `In development`。模型 `GLM 5.2-ArkTS-SPARK`。输入为合成任务：`schemaVersion=2.1.0`、`channel=USER_REQUEST`、`sourceEventId=synthetic-event-001`、`correlationId=synthetic-corr-001`、`userGoal=整理一份三页课堂汇报提纲`；通过 Start `query:String` 提交 JSON 字符串。无真实个人数据、传感器数据或密钥。

| 调用 | 平台节点与耗时 | 断言 | 状态/等级 |
|---|---|---|---|
| Trial 1 | Start、Foundation Model、End 均 Success；总 26.42s，2026-11-16 21:30:49～21:31:15 | 模型对象含 STEP、匹配 ID、五步；End `responseContent` 将对象转成单引号字符串，**严格 JSON 断言失败**。 | FAIL / E2（输出契约） |
| Trial 2 | 三节点均 Success；总 24.90s，2026-11-16 21:35:09～21:35:34 | 改为模型 Text `raw_output:String` 后，最终文本为双引号 JSON；八字段、STEP、匹配 ID、五个步骤符合草稿校验。平台页面刷新后仍显示已保存的 Text 模式和提示词。 | PASS / E2（平台预览） |

2026-11-17 只读复核 Debugging 历史时，还看到 2026-11-16 21:39:08 的第三条合成输入记录：三节点 Success、总 20.80s、End `responseContent` 为可解析 JSON。历史页面没有显示发起人，不能归于本代理，也不计入上表的两次调用上限；它同样不是 Runtime API 证据。

第二次预览的最终文本保存在 `evidence/platform-trial-2026-11-16.json`；仅记录合成输入、最终答案与节点状态，不记录模型思考文本或凭证。平台 Trial Run 页面未给出可核实的 API `requestId`、`sessionId`、Runtime Name、真实 SSE 或 HTTP 状态，均记 **NOT_RUN**。模型调用次数已用满本轮上限 **2/2**，本轮不再调用。

本地验证：草稿校验命令 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/agentarts-planner-draft.test.mjs` → **4/4 PASS / E1**；纯 TaskPlan 映射与本地 Workflow 回放命令 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/agentarts-planner-mapping.test.mjs` → **6/6 PASS / E1**；候选后端绑定命令 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/agentarts-planner-provider.test.mjs` → **4/4 PASS / E1**；全量 `node --disable-warning=ExperimentalWarning --test --test-reporter=tap tests/*.test.mjs` → **201/201 PASS / E1**，日志 `evidence/app-all-2026-11-17.tap`。本地测试的伪 SSE、假 fetch 和平台结果回放仍是 E1。真实 API、App 正式调用和手机/手表回执 **NOT_RUN**；预览成功不能替代它们。

正式 API 前置条件仍缺：提交/部署版本的实际 Runtime Name、访问域名、受控后端鉴权，以及平台终结 SSE 的真实输出包络。2026-11-17 Plan Usage 显示免费 MaaS 已用 2.94K/2M Tokens、CUs 0/20；这是调测额度，不是正式 API 余额。账号持有人已将 `GLM 5.2-ArkTS-SPARK` 与 `GLM-5.2` 设为 `Subscribed`；本代理在同账号 AgentArts「Authorization Management → Model」只读复核状态、`token-based billing` 与所选模型的控制台单价（E2）。官方[Runtime API](https://support.huaweicloud.com/api-agentarts/InvokeRuntime.html)、[免费额度说明](https://support.huaweicloud.com/lowcode-agentarts/agentarts_05_0186.html)和[工作流 API 使用说明](https://support.huaweicloud.com/lowcode-agentarts/agentarts_05_0055.html)是接口与计费依据，不是本账号调用证据。所选 `GLM-5.2-ArkTS-SPARK` 的[公开 MaaS 单价](https://support.huaweicloud.com/price-maas/price-maas-0002.html)为缓存命中输入 ¥2.4、普通输入 ¥9.6、输出 ¥33.6／百万 Token；控制台显示相同单价。草稿未发布；本代理未购买额度或尝试正式 API，模型调用仍为本轮 2/2 次预览。

以下 2026-11-15 记录是账号暂停期间的历史状态。

日期：2026-11-15。真实 API：**BLOCKED / 无 E3 证据**；平台预览：**NOT_RUN**；App 正式调用：**NOT_RUN**；模型调用次数：**0 / 上限 2**。

控制台 `cn-southwest-2` 的 AgentArts 页面显示账号因异常暂停，并提示提交服务工单。账号内 Agent/Workflow、Runtime Name、访问域名、发布状态、鉴权配置和剩余额度均无法确认。因此未创建工作流、未发布、未调用模型，也未生成请求 ID、Session ID、耗时或响应。不得用下述官方示例值填充实际运行记录。

本轮新增的 `AgentArtsSse.ts` 用人工合成 SSE 测试为 **5/5 PASS / E1**，仅证明本地终结事件解析和错误拒绝；与本报告的真实 API 状态 **BLOCKED** 分开记录。

随后新增的后端专用 `scripts/agentarts-runtime-client.mjs` 以假 `fetch` 的人工合成响应验证请求包络、超时和错误边界，为 **4/4 PASS / E1**（`evidence/agentarts-runtime-client.tap`）。App 全量复跑 **187/187 PASS / E1**（`evidence/app-all-current.tap`）。它没有发送真实 AgentArts 请求，模型调用次数仍为 **0**。

官方[调用 API](https://support.huaweicloud.com/api-agentarts/InvokeRuntime.html)给出 `POST /runtimes/{runtime_name}/invocations`；[工作流调用说明](https://support.huaweicloud.com/lowcode-agentarts/agentarts_05_0055.html)指出发布前置条件和潜在费用；[响应事件说明](https://support.huaweicloud.com/api-agentarts/agentarts_07_0056.html)指出 SSE `workflow_finished`、`exception`、`error` 等事件。以上是接口文档证据，不是本账号实际调用路径。

恢复后最小测试：先只读确认是否有等价资源；若无且允许创建，仅建 `FA_TaskPlanner_v0_1`；确认模型额度和费用上限、发布前置条件；从真实“调用路径”复制 runtime name/访问域名；用一个不含个人数据的合成任务调用至多两次。保存脱敏请求与 SSE 响应、requestId、sessionId、耗时、工作流版本、状态和校验断言。费用不确定时停在调用前。API Key 仅置于受控后端或凭证管理，不写入客户端、仓库和报告。
