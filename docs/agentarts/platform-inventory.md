# AgentArts 平台资产盘点（2026-11-15）

## 2026-11-16～17 复核（当前状态）

账号限制已解除。以下为 AgentArts 控制台的直接观察（E2），早先的账号暂停记录仅作历史保留。

| 项目 | 状态 | 实际观察与边界 |
|---|---|---|
| 账号与区域 | PASS / E2 | 控制台显示 `hw084950654`、`CN Southwest-Guiyang1` / `cn-southwest-2`。具体项目、工作空间标识未在所见页面确认，仍为 NOT_RUN。 |
| 现有 Agent / Workflow | PASS / E2 | 创建前，Managed Agents、Single Agent 与 Workflow 清单均显示空状态；没有可复用的本项目工作流。资产广场模板未计入。 |
| 新增核心 Workflow | PASS / E2（草稿） | 唯一新增 `FA_TaskPlanner_v0_1`，ID `1542f0de-f841-46a0-875d-cfd2d34d2263`；[控制台草稿](https://console.huaweicloud.com/agentarts/?region=cn-southwest-2&locale=en-us#/home/agent-center/app-flow/flow?id=1542f0de-f841-46a0-875d-cfd2d34d2263&tabId=) 显示 `In development`、`Saved`，2026-11-17 再次复核。未提交版本、部署或公开发布。 |
| 节点与绑定 | PASS / E2 | 从资产列表打开草稿后直接复核：Start `query:String` → Foundation Model `GLM 5.2-ArkTS-SPARK`，Text `raw_output:String` → End `result` 引用 `raw_output`；短期记忆关闭。提示词列出 `USER_REQUEST` 与 `AUTHORIZED_CONTEXT_EVENT`，但只有前者完成平台 Trial Run；后者的运行验证为 NOT_RUN。无 Knowledge Base、Plugin、MCP 或 Personal Memory 节点/绑定。平台 Plugin 清单在创建前为空。 |
| 模型与当前额度 | PASS / E2 | 创建前 Model 页面显示一个已配置 Provider 和一个 OpenAI Protocol 模型服务；草稿实际选用平台模型 `GLM 5.2-ArkTS-SPARK`。2026-11-17 Plan Usage 显示 Trial Edition、2026-11-30 23:59:59 到期，0/20 CUs、免费 MaaS 已用 2.94K/2M Tokens。该余额仅供平台调测/试运行，不能用于正式 API 调用。 |
| 所选模型正式授权 | PASS / E2（订阅状态） | 2026-11-17 同账号、同区域的 AgentArts「Authorization Management → Model → MaaS model subscribe」列表显示 `GLM 5.2-ArkTS-SPARK` 与 `GLM-5.2` 均为 `Subscribed`，操作为 `Disable Service`。两者均为 `token-based billing`；所选 SPARK 的控制台单价为普通输入 ¥0.0096、输出 ¥0.0336、缓存输入 ¥0.0024／千 Token，TPM 1,000,000、RPM 100。订阅操作由账号持有人完成；本代理仅只读复核。该页面状态不证明工作流 Runtime 已部署或可调用。 |
| Runtime / API | BLOCKED | 草稿没有已提交版本或可核实 Runtime Name、API 访问域名；未执行真实 API。官方文档的 API 路径不等于本账号可调用的实际地址。 |

本代理发起的平台模型试运行共 **2/2** 次，均为低风险合成任务。第二次预览成功且最终文本为严格 JSON。调试历史另显示 2026-11-16 21:39 的第三条合成任务成功记录，其发起人未知，不计入本代理的调用次数；详情见 `agentarts-call-test-report.md`。`PASS / E2` 仅指平台草稿与预览，不能代表真实 API、App 或设备联调。

官方[免费额度说明](https://support.huaweicloud.com/lowcode-agentarts/agentarts_05_0186.html)和[工作流 API 前置检查](https://support.huaweicloud.com/bestpractice-agentarts/agentarts_06_0022.html)说明正式 AgentArts API 不使用赠送的免费 Token，需接入可计费模型。所选 `GLM-5.2-ArkTS-SPARK` 在[官方 MaaS 模型公告](https://support.huaweicloud.com/bulletin-maas/bulletin-maas-0001.html)列为西南-贵阳一的预置服务，[模型 API 文档](https://support.huaweicloud.com/model-call-maas/model-call-021.html)列出其 MaaS API 型号 `glm-5.2-arkts-spark`；这证明**模型服务的一般 API 能力**，不证明本账号 AgentArts Workflow Runtime 已可调用。[2026-11-16 MaaS 文本计费表](https://support.huaweicloud.com/price-maas/price-maas-0002.html)列出的该型号公开单价为缓存命中输入 ¥2.4、普通输入 ¥9.6、输出 ¥33.6／百万 Token，不区分忙闲时；2026-11-17 控制台显示相同单价。账号持有人已将所选模型设为 `Subscribed`，但适用折扣和费用上限未核实，本代理未发起新的付费调用。

## 2026-11-15 历史快照（账号当时暂停）

状态：**BLOCKED**。证据等级：控制台页面 E2；资源列表本身未取得，不能据此断定资源不存在。

## 当前可核实事实

| 项目 | 结果 | 证据与限制 |
|---|---|---|
| 控制台 | 浏览器已有 `https://console.huaweicloud.com/agentarts/?region=cn-southwest-2#/home/app-library` 页面 | 页面显示 AgentArts 资产广场，不是“我的工作流”清单。 |
| 区域 | `cn-southwest-2`，页面显示 `CN Southwest-Guiyang1` | 当前页面值；项目与工作空间未显示。 |
| 账号 | 页面显示账号标识 `hw084950654`，同时显示“Your account has been suspended because an exception occurred. To restore your account, submit a service ticket.” | 不在报告中记录凭证；账号受限使后续资产和费用信息不可可靠核查。 |
| Agent / Workflow / 版本 / 部署 | **BLOCKED** | 未能进入账号内资源清单；不得把资产广场模板算作本项目资源。 |
| Plugin / KB / 模型 / 额度与费用 | **BLOCKED** | 未读取账号实际配置；知识库只读盘点亦未完成，且本轮不更新或绑定。 |
| 等价工作流复用判断 | **BLOCKED** | 必须先恢复账号访问，再在本账号/区域/项目内按名称和用途查找。未创建 `FA_TaskPlanner_v0_1`。 |

本地 `Wang-B-Agent/workflows/dual-channel-sgcw/workflow.yaml` 是旧版 `0.1.0` 声明，不是 AgentArts 资源或官方导入文件。小艺意图 ID、端侧 A2A ID 均不得充当 AgentArts 资源 ID。

## 官方接口能力与尚缺条件

华为云[调用工作流/智能体 API](https://support.huaweicloud.com/api-agentarts/InvokeRuntime.html)说明 `POST /runtimes/{runtime_name}/invocations`，请求包含 `Authorization`、会话 ID 与由工作流开始节点决定的 `inputs`；响应为事件流。运行时名称和访问域名应从实际工作流/运行时详情取得，不能猜测。官方[工作流 API 使用说明](https://support.huaweicloud.com/lowcode-agentarts/agentarts_05_0055.html)要求工作流发布，并指出调用可能消耗 Token、产生费用。故文档证明一般能力，**不证明本账号可调用、已发布或可免费调用**。

账号恢复后只读复核顺序：账号/区域/项目/工作空间 → 我的 Agent/Workflow 及其版本/状态 → 等价工作流 → Runtime Name/访问域名 → 模型和额度/计费 → Plugin/KB 绑定。费用不明时停止真实调用。平台资源变更上限：最多新增一个核心测试 Workflow；本轮实际新增数 **0**。
