# FocusAnchor 建模边界与阶段门禁

日期：2026-10-29。上位约束：`docs/architecture/FocusAnchor_Architecture_Charter_v0.1.md`；当前技术基准：`<LOCAL_PROJECT_ROOT>/6_文档/技术框架/FocusAnchor 建模工作约束与系统技术框架 v2.0.pdf`。

## 已确定的控制权

| 组件 | 允许输出 | 不得执行 |
|---|---|---|
| M1 | 状态证据、来源、时间、信号质量、缺失、校准与不确定性；可为 `unknown` | 由心率直接断定情绪/专注或医学诊断；通知或调用 Agent。 |
| M2 | `ABSTAIN/DEFER/ASK/SUGGEST` 语义的候选、依据、策略版本；实测数据仅支持有限的 receptivity/timing 结论 | 将 receptivity 当作真实干预收益；写 Task、推送或越过 G0。 |
| G0/端侧 | 依许可、勿扰、暂停、频率、质量、OOD/不确定性及服务状态确定性否决 | 接受模型分数覆盖硬性限制。 |
| 现有 Agent/工作流 | 仅在用户明确许可和现有安全路径允许时提供任务建议 | 建模路线直接修改、部署或替换。 |

Channel U 用户主动请求不等于主动介入；Channel C 授权情境事件先过 G0。`suggest` 进入 Agent 前必须有当次明确许可。坏信号、未知、OOD、模型不确定和服务故障应拒判或安全降级，不能默认稳定状态。原始生理序列不送入 LLM。

## 实验边界

- WESAD wrist 作为 M1 首个基线，比较 RF/XGBoost，资源允许再研究 1D-CNN；30/60/120 秒窗口，主体级切分。
- M1 内部测试、校准集、WESAD→NURSE 外部测试分开；外部标签不可用于 zero-shot 调参。报告 Macro-F1、Balanced Accuracy、AUROC、AUPRC、ECE、Brier、校准与逐主体结果，不预设达标数值。
- Mobile Phone Use 作为 M2 receptivity/timing 基线，按用户留出；K-EmoPhone 访问获批后才能用。不同数据标签不等于 FocusAnchor 用户任务启动效果。
- 数据集先核实来源、许可、下载完整性与哈希。当前 `9_Dataset` 仅观察到 `WESAD.zip` 和部分解压目录；这不等于 Task 1 完成或 WESAD 已校验。访问/许可受限记录 `NEEDS_MANUAL_REVIEW` 或 `BLOCKED_ACCESS`，继续独立任务。
- 训练与校准产出配置、seed、版本/哈希、每折预测、指标与单命令入口。没有运行的指标一律 `NOT_RUN`。

## 共享接口与安全依赖

章程仅冻结建议/询问/延后/不介入的语义类别。v2.0 PDF 的 1.0 示例与并行工作流 2.1.0 草案的字段和枚举不同；两者目前都不是本分支已实现接口。需要在 Task 6–7 前提出 `Change-ID`：字段映射、来源与质量、拒判、版本兼容、日志、用户许可、错误码和回退方案；工作流专题与项目负责人审查后方可接入。

本分支不得修改现有 Agent、工作流、`XiaoyiBridge`、`WatchSyncService` 传输/ACK、`TaskFileService` 事务、FormKit 回写、生理采集/推断、权限/签名或生产配置。UI/UX V3.1 保留隔离；负责人查看效果前不合并。工作流部署冻结，小艺到 AgentArts 迁移待负责人更新。

## 阶段顺序及当前状态

1. Task 0：仓库/环境/接口审计，**PASS（E0）**；见 `docs/integration-map.md` 与 `docs/task0-file-inventory.md`。
2. Task 1–5：数据与 M1/M2，**NOT_RUN**；先数据许可、完整性和主体 ID 核查。
3. Task 6–7：模型/接口可用后做服务与端侧门控，**NOT_RUN**；共享契约与安全审查为前置依赖。
4. Task 8：复现材料与阶段技术报告，**NOT_RUN**。

Task 0 没有模型指标。当前审计仅提供 E0 静态证据；不宣称设备、服务或 Agent 闭环。
