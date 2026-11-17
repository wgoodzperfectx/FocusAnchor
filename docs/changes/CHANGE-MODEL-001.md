# CHANGE-MODEL-001 — 建模回放接口与共享契约映射提案

状态：**PROPOSED**；日期：2026-11-01，2026-11-14 补充外部验证证据；提出专题：FocusAnchor 建模。此提案未获项目负责人或工作流专题批准，不更新共享 `architecture-contract.md`，不允许合并为生产接口。

## 问题与证据

1. 章程只冻结 `ContextFeatures` 与 `InterventionDecision` 的语义下限；最终字段、枚举和版本属于待批准的共享契约。
2. v2.0 Markdown 的 `PhysioSample` 示例是一个采样点，但当前 WESAD M1 是 30/60/120 秒腕部特征窗口模型。单点心率不能替代窗口输入；基线手机的 `HeartRateService` 仍由 `Math.random` 生成模拟 BPM。
3. M2 Mobile Phone Use 模型仅训练问卷通知 10 分钟内点击代理，不能直接提供 `P(need)` 或介入收益。`TaskContext` 和许可必须由端侧现有状态源提供，不能从公开数据推造。
4. 并行未提交的 `WorkflowV21Contracts.ts` 草案采用 `2.1.0` 和 `INTERVENE/DEFER/ASK/ABSTAIN`；文档示例采用 `1.0` 和 `suggest/defer/ask/abstain`。两者尚无获批映射。
5. 2026-11-14 WESAD→NURSE 固定 RF 30/60/120 秒外部测试的原始概率 AUROC 为 0.545/0.546/0.528，ECE 为 0.529/0.491/0.476；Platt/isotonic 未迁移成功。详见 `reports/m1_cross_dataset.md`。因此真实压力分数目前不具备作为主动触达输入的证据。

## 拟议职责与内部原型契约

| 边界 | 建模侧职责 | 需要共享确认的字段/语义 |
|---|---|---|
| `M1 / Context Estimator` | 从已预处理的窗口特征给出概率、质量、uncertainty/OOD；坏信号返回 unknown | `PhysioWindow` 或等价窗口摘要、特征版本、窗口长度、采样来源、质量、模型/校准版本；`PhysioSample` 不能被当成已足够的模型输入。 |
| `M2 / Intervention Policy` | 从合法的手机情境特征产生 receptivity 分数和保守候选动作；不计算真实 benefit | `receptivity_score` 来源、`need_score` 缺失时的语义、候选 action/reason_codes、模型版本、uncertainty/OOD。 |
| `G0 / Hard Gate` | 端侧按许可、DND、当次确认、冷却、活动、质量、拒绝记录确定性裁决 | `allow_proactive_prompt` 的状态源、`user_requested_help` 与“当次明确许可”的区分、DecisionLog、服务失败降级。 |
| `Channel U / USER_REQUEST` | 用户主动触发既有手动路径 | 用户请求事件 ID、何时允许建议。 |
| `Channel C / AUTHORIZED_CONTEXT_EVENT` | 授权情境事件仅在 G0 允许后向用户询问 | 情境来源、授权凭据、取消与撤回、限频。 |

Task 6 的 FastAPI 先用 `0.1-replay` 内部契约，端点仅接受本地回放特征；响应必须标记 replay、candidate、model version 和拒判原因。该契约不写入现有 ArkTS `WorkflowV21*`，不代表共享 Schema 已批准。M2 `ASK` 只能是候选，绝不由服务发送通知或调用 Agent；`SUGGEST` 候选也不得自动执行。

## 两专题影响矩阵

| 模块 | 影响 | 当前处理 |
|---|---|---|
| M1/M2 | 新增窗口与手机情境输入、可审计模型版本 | 仅建模 worktree 内部实验。 |
| Workflow/Intent | 需要候选动作映射、失败/拒判路径、DecisionLog | 待工作流专题确认；不修改并行脏工作区。 |
| App/UI | 需要端侧 G0 与回放调试入口 | 只可新增隔离原型，不能接管现有提醒或 Agent。 |
| FormKit/Watch/Platform | 暂无直接读写 | 不修改。 |

## 兼容、安全、验收与回退

- 兼容：若共享契约批准不同枚举/字段，内部原型增加显式 adapter 和版本检查；未知版本拒判，不做宽松猜测。`INTERVENE` 不能默认为 `SUGGEST`，须明确当次许可语义。
- 隐私：原始 WESAD/MPUD 记录、用户标识、BVP/EDA 序列不进入 API fixture、日志或 Git；只保存合成回放特征。协议正文未归档前不分发 MPUD 原始数据或模型。
- 门槛：坏质量、缺失字段、OOD、模型文件缺失、超时和未知版本返回 `unknown/abstain`；任何高分不得越过主动许可。验证服务单测、端侧门控单测、OpenAPI 契约、编译及回放；设备结果单独标注。
- 外部泛化门槛：当前只讨论 `0.1-replay` 合成回放契约。未经重新设计并通过独立外部验证，不把 WESAD 压力概率映射为真实 `ContextFeatures` 的可用压力状态，也不以其触发 Channel C 主动建议。
- 回退：原有手动 Agent 路径不变；不启用新网络入口或周期通知。删除实验服务/调试入口即可回退；无生产数据迁移。

待决：窗口契约、模型分数阈值、`need_score` 缺失表示、当次授权事件、Workflow 2.1.0 映射、网络地址/TLS 与真机验证方案。项目负责人和工作流专题批准后才能更新 `architecture-contract.md` 或合并生产接入。
