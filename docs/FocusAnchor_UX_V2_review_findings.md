# FocusAnchor UX V2：G0–G1 只读审查记录

日期：2026-10-14。审查框架：[FocusAnchor_UX_V2_review_framework.md](FocusAnchor_UX_V2_review_framework.md)。以下结论仅基于当前源码和 Git 状态，不代表编译、模拟器或真机验证。

## G0：工作区与范围

- 主体工程：`Huang-A/pig-master`，当前分支 `master`。存在大量未提交修改及未跟踪的 Agent、Guide、卡片文件；不得重置或覆盖。
- 服务卡片已在主体的 `entry/src/main/module.json5` 声明，并有 `formability/FocusTaskCardAbility.ets`、`widget/pages/FocusTaskCard.ets`、`services/FocusCardService.ets`。其代码仍未跟踪，集成是否完成尚缺编译和端到端证据。
- `Zeng-C` 是独立元服务工程，本轮不作为主体状态源，也不从中覆盖文件。

## G1：需求—证据—差距矩阵

| 需求 | 现有文件/符号与证据 | 差距 | 拟修改文件 | 风险 |
| --- | --- | --- | --- | --- |
| Home 显示真实任务与第一步 | `entry/.../pages/AppTabs.ets` 的 `HomeTab` 主要展示心率和 Focus、Guide、Remind 按钮；`AppState.getPendingTasks()` 可取任务 | 没有 Home 的任务/Action 空状态；独立 Guide 仍是主入口 | `pages/AppTabs.ets`、`pages/Index.ets` | 导航调整须保留设置、提醒、悬浮球 |
| Task 显式拆分并标明来源 | `TasksTab.requestAdvice()` 调用 `XiaoyiBridge.askAdvice()`，结果保存为 `task.insight`；`FocusAnchorRouter.proposeFirstStep()` 有本地规则分支 | Task 页未产出持久化、带来源和 ID 的 Action；建议文字不能冒充拆分结果 | `pages/AppTabs.ets`、`models/AppTypes.ets`、`services/AppState.ets`、现有 Agent 接口 | Agent 失败与规则降级必须分辨 |
| Focus 工作台与闪念收件箱 | `pages/FocusPage.ets` 当前围绕 BPM 视觉；`FocusAnchorSession` 在主体 Agent 范围内保存 `ThoughtRecord` | 无独立 FlashNote 契约、手表采集同步、显式转换及幂等关联 | `pages/FocusPage.ets`、`models/AppTypes.ets`、`services/AppState.ets`、`services/WatchSyncService.ets`、手表页面 | 不能把闪念混入当前 Task |
| Action 跨端一致及回写 | `StudyTask.focusStep` 只有 `text/status/updatedAt`；卡片 `FocusCardService.apply()` 以 `taskId` 更新任务文件并推送手表；手表 `Index.ets` 可改 `focusStep` | 缺 `actionId/revision/source`；卡片/手表对旧步骤和重复事件的判定不充分；整包 `updatedAt` 合并可能覆盖并发修改 | `models/AppTypes.ets`、`services/AppState.ets`、`FocusCardService.ets`、`WatchSyncService.ets`、`wear/.../Index.ets` | 与当前卡片未提交代码直接重叠，修改前须确认稳定基线 |
| 监测与陪伴两维状态 | `HeartRateService.start()` 和手表 Focus 页面使用随机 BPM；`focusLevelFromBpm()` 把单值映射为等级 | 无数据来源/时效、MonitoringState/CompanionState；不能把模拟心率呈现为真实数据 | `models/AppTypes.ets`、`services/DomainServices.ets`、Home/Focus/手表显示 | 不得据单个 BPM 推断心理或专注状态 |
| 九张状态图 | `8_Drive/图标和logo` 有一张六态监测合成图和一张三态陪伴合成图；主体 `status_*.png` 为旧 Guide 流程 | 缺九张独立可加载且有语义资源 ID 的图片 | 双端 `resources/base/media`、轻量角色组件 | 不能把合成图直接当单状态图 |

## 当前验证状态

- 静态源码与 Git 状态：已审查。
- 编译、自动化测试、模拟器、真机：未执行。
- 框架 T01–T12：均未形成可记录的通过证据。

## 进入实现前的门禁

1. 保留并核对当前卡片接入文件的稳定版本，先验证至少能编译；后续在其接口上增量修改。
2. 先审定 Action/FlashNote/SyncEvent 的最小契约及旧 `focusStep` 迁移规则，再调整页面。
3. 九态图片需成为独立资源，且状态来源与模拟数据标识得到明确实现；缺真实设备能力时显示未知或模拟状态。
