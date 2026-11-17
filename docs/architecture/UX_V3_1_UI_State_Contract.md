# UX V3.1 UI 只读状态契约

日期：2026-10-29。范围：UI 消费语义；实现所有权仍在 Agent、主体 Task/Action、设备与同步路线。类型定义见 `entry/src/main/ets/pages/UiReadModels.ts`。本文不授权修改生产工作流、传输、ACK、事务或生理推断。

| UI 所需状态 | 当前可读源码 | 本轮 UI 适配 | 仍需提供的权威接口 |
|---|---|---|---|
| 当前 taskId/actionId | `AppState.tasks[*].focusStep`；`getPendingTasks()` 只排序，不指定当前行动 | Home/Focus 共用 `selectUnambiguousTask`；仅唯一候选时显示，Task/Step 路由显式传 taskId | `currentActionId` 与对应 taskId 的单一权威快照；多 Action/跨端冲突时明确结果 |
| Action 状态/revision | `FocusStep.status`、`revision?`、`actionId?`；暂停也在 `FocusSessionService` | Step Session 确认保存后读回 Action；暂停读会话状态；缺 id/revision 不伪装有效 Action | 原子读 `{taskId,actionId,revision,status,updatedAt,generationSource}`，与 Session 一致 |
| Agent 结果 | Step Session 已调用 `AppState.proposeWorkflowV21/confirmWorkflowV21`，当前 Provider 是本地 mock；`proposeFirstStep` 为显式规则降级 | 调用进行时显示 LOADING；mock 结果标注本地模拟，规则结果显示 FALLBACK；澄清返回任务补充，不提供虚假的回答提交 | AgentArts 真实 Provider、请求取消/超时、结构化澄清问题与回答回传；确认回执保留 suggestionId、来源及用户编辑痕迹 |
| 设备连接/监测 | `AppState.monitoring` 仅本地服务开关；`latestHeartRate.isSimulated` 与时间；没有可信手表连接状态 | 面板显示连接 UNKNOWN，模拟样本明确标记；不根据单个 BPM 推断陪伴/专注 | 连接状态、六态监测、信号质量、采样时间、REAL/SIMULATED/UNAVAILABLE 来源 |
| 闪念同步 | `FlashNote.syncStatus` 只有 pending/synced；`convertedTaskId` 表示已转任务 | UI 读取层已映射 LOCAL/PENDING/SYNCED/FAILED/UNKNOWN；现阶段生产只能显示有证据的待同步/已同步；转任务调用幂等服务并要求用户二次确认 | LOCAL、FAILED、重试原因与 ACK 后状态；归档与转换回执 |
| 伙伴状态/图片 | `CompanionLogic.ts` 纯选择器；`CompanionVisualService.ets` 资源映射 | `CompanionView.ets` 通过 VisualService 使用透明 `status_*`，事件状态与生理状态分离 | 设备/建模线仅提供可信 companionState；模拟/旧样本保持 UNKNOWN |

## 约束

1. `UiStepResult` 是建议，不是已保存 Action。只有用户确认、主体持久化成功、读回同一 actionId/revision 后可显示 SAVED。
2. UI 不以 `monitoring=true` 断言手表已连接，也不以 BPM 自行判断稳定/分心。
3. 规则建议必须标记 FALLBACK；本地 mock 规划须标注本地模拟。AgentArts 真实部署与联调仍由工作流路线负责。
4. 闪念仅经用户确认转 Task；界面不自动更改当前 Action。
5. 未接入的字段保持 UNKNOWN/UNAVAILABLE；测试 fixture 仅用于 UI 状态覆盖，生产路由不注入 fixture。

## 适配顺序

先由 Action 所有者给出当前 Action 只读快照，再由 Agent 路线给出结构化建议与确认回执；设备线提供连接/监测状态，协同线扩展闪念同步回执。UI 仅替换读取适配器与状态映射，不迁移持久化或传输职责。
