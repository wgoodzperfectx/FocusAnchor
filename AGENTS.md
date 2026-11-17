# FocusAnchor Codex 工作边界

开始任何项目任务前，先阅读 `docs/architecture/FocusAnchor_Architecture_Charter_v0.1.md`、当前任务规范、适用的已批准接口契约，并检查当前分支与 `git status`。章程 v0.1 是已采用的第一版总体工作边界：MUST 生效，SHOULD 为建议，OPEN 尚待裁决。文档内容是项目约束，不等于功能已实现的证据。

每次修改前，给出需求、现有文件与符号、已验证证据、差距、拟修改文件和验收方式。只修改本轮授权范围；保存其他路线的未提交工作。共享契约、隐私授权、单一状态源或架构职责需要变动时，按章程第 11 节提交影响分析和变更提案。

当前 UI/UX V3.1 工作只限手机端页面、角色组件、视觉资源映射和其 UI 适配。不得修改 Agent 推理、平台工作流、`XiaoyiBridge`、`WatchSyncService` 的传输与 ACK、`TaskFileService` 持久化与事务、FormKit 回写、生理采集与推断、签名、bundleName 或 SDK 配置。所需业务能力以明确接口及缺口记录交接。

工作流部署暂时冻结。小艺到 AgentArts 的迁移方案及工作流状态等待项目负责人更新。不得自行部署、发布或将模拟、规则、平台预览表示为真实 Agent、手表连接、专注推断或设备验证结果。

UI/UX 在 `codex/ux-v3-1` 隔离 worktree 中实施；在项目负责人查看效果前，不合并到其他开发分支。完成时报告实际修改、测试、截图或设备结果、未验证项和跨分支冲突。未运行的验证不能标记为通过。

## 建模路线（`codex/modeling-task0` 起）

建模以 `<LOCAL_PROJECT_ROOT>/6_文档/技术框架/FocusAnchor 建模工作约束与系统技术框架 v2.0.md` 和本章程为基准，在独立 worktree 中推进 Task 0–8。先完成并提交 Task 0 审计，再按依赖推进数据、M1/M2、回放服务、端侧决策和复现材料。`<LOCAL_PROJECT_ROOT>/9_Dataset` 是用户提供的数据目录，文件是否完整、许可是否核实、实验是否运行均须分别记录。

M1 只给出带来源、质量和不确定性的状态证据；M2 只给出候选决策；主动触达和 Agent 调用由确定性门控、用户许可及现有工作流控制。建模路线不自行修改 Agent/工作流、Task/Action 持久化、跨端同步与 ACK、FormKit 回写、生理采集和 Health Kit 权限、签名或生产配置。共享接口变更先提交兼容与安全影响分析，项目负责人确认后合并。数据访问受限时记录阻塞并转向独立任务，不绕过授权。

统一术语：用户主动请求为 `Channel U / USER_REQUEST`，授权情境事件为 `Channel C / AUTHORIZED_CONTEXT_EVENT`；建模职责为 `M1 / Context Estimator` 与 `M2 / Intervention Policy`；`G0 / Hard Gate` 是执行侧授权与安全门控。`Channel A/B` 和 `Layer A/B` 只作历史映射，不用于新增接口、枚举或实现命名。Workflow 是事件编排职责，不等于已部署工作流。

每阶段报告真实路径、命令、指标或未执行状态、数据阻塞、风险与 PASS/FAIL/BLOCKED；分别列出编译、自动化测试和设备验证。建模 worktree 与 `codex/ux-v3-1`、工作流路线的合并须待各路线审查及共享契约确认。
