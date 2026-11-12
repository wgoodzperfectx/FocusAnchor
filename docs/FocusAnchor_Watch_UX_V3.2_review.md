# FocusAnchor Watch UX V3.2 审查与实施记录

日期：2026-11-12
工作分支：`codex/watch-ux-v3-2`
基线：`26da259 chore(wear): capture reviewed sync baseline`（从审查时的 `81d3a92` 源码状态建立独立 worktree）

## 审查结论

录屏（2026-11-01）展示的 Wear 交互以多页 Swiper 为主，首页、任务页和闪念页并列；首页的任务入口和创建/编辑反馈占据手表主流程。录屏中的任务内容存在占位/反馈路径，复杂编辑最终提示回手机。Wear 当前主页面 `wear/src/main/ets/pages/Index.ets` 也包含首页、任务创建/编辑和闪念输入，造成当前第一小步与次级功能竞争圆屏空间。

源码审查定位如下：

| 范围 | 当前源码 | 差距/处理 |
|---|---|---|
| 首页与分页 | `wear/src/main/ets/pages/Index.ets` | 原多页 Swiper/导航点改为“当前一步 / 闪念”双页入口；真实空态不补造步骤 |
| Task 创建与反馈 | 同上；任务投影由手机 `tasks_sync` 提供 | 手表侧不再提供复杂 Task 编辑；开始/暂停/继续为主操作，完成/换一步收至次级入口 |
| 闪念输入与保存 | 同上；`WearFlashNoteService.ts` 队列 | 首次点击即请求焦点并调出系统输入；本地队列持久化后才显示已保存在手表；KV 投递仅显示等待同步；匹配 ACK 才显示同步已确认 |
| 小艺/ASR | Wear 源码未直接调用手机端 `XiaoYiBridge`；使用系统 `TextInput` 和输入法 | 复用系统键盘的输入/麦克风能力，不新增 ASR/授权实现；许可仍由系统界面管理 |
| 心率模拟/监测页 | `wear/src/main/ets/pages/FocusPage.ets` | 移除模拟 BPM、黄色圆环与蓝色波形；“心率”入口打开 P2 六状态整图，真实状态缺失时显示未知/数据未提供 |
| 伙伴资源映射 | 手机端正式素材与 `CompanionLogic` 为映射参考；Wear `WearVisualService.ets` | P1 八种交互图、P2 六种监测图、P3 三种用户状态图按状态映射，不随机轮播 |
| 连接、KV、ACK | `Index.ets` 消费现有 distributed KV；闪念 ACK 来自 `flash_acks_sync`；手机同步服务是 ACK 权威 | 不改手机 `WatchSyncService`、Task 持久化或 ACK 事务；离线保留本地队列 |
| 设置 | `wear/src/main/ets/pages/SettingsPage.ets` | 设置从主任务流程移到次级页面；保留语言、权限/设备信息并统一深绿配色 |

## 页面线框

```text
圆屏首页（默认）                 圆屏闪念页
┌──────────────────┐          ┌──────────────────┐
│ 大幅小步伙伴形象   │          │      闪念        │
│ 当前第一步（最多2行）│          │ 语音记闪念（主按钮）│
│ [开始/暂停/继续]   │          │ 系统输入法/麦克风 │
│ 完成 / 换一步 ··· │          │ 保存     取消    │
│ 同步反馈 / 空态    │          │ 本地/待同步/失败  │
│ 心率监测 ›         │          │ 重试（仅同步失败）│
├──── 当前一步 · 闪念 ┤          ├──── 当前一步 · 闪念 ┤
└──────────────────┘          └──────────────────┘
```

监测页显示完整 P2 状态图、状态标签、来源/数据质量说明、设置及返回；未接入实时状态契约时为“状态未知 / 设备状态未提供”。首页在存在当前一步时显示 P1 行动形象；手表静置且手机提供可信用户状态时显示 P3 稳定/波动/需支持形象。用户状态未知时不伪装成稳定，显示中性待机形象和未知文案。

## 文件级影响与接口缺口

- 修改 `wear/src/main/ets/pages/Index.ets`、`FocusPage.ets`、`SettingsPage.ets`：页面布局、导航和 UI 状态消费。
- 新增 `wear/src/main/ets/services/WearUiState.ts`：当前 action 选择、P1/P2/P3 状态到素材 ID 的纯映射、六状态过期校验、闪念文案及可测状态投影。
- 新增 `wear/src/main/ets/services/WearVisualService.ets`：P1/P2/P3 状态到正式图片资源映射。
- 新增 `tests/wear-ux-v3-2.test.mjs`：纯状态/队列验收。
- 未修改 `WatchSyncService`、手机 `AppState`/`TaskFileService`、Agent/Workflow、生理推断、权限声明或签名配置。

业务契约仍未完全接通：手机任务 bundle 尚无已确认的 `currentActionId` 稳定生产契约；监测六状态和 P3 用户状态也没有接入 Wear 的实时生产者。消费端接受可选 `currentActionId`/`companionState`，对缺失/过期的监测数据显示未知；这两个字段目前只是 UI 消费接口，不代表手机已生产。当前 action 选择只在唯一候选时回退，歧义时留空。不创建第二套监测或 Agent 判断服务。

## 并行修改冲突风险与隔离

主 worktree `Huang-A/pig-master`（`codex/workflow-v21`）和 V3.1 worktree（`codex/ux-v3-1`）在本轮开始时均有大量未提交文件，且包含 Wear 页面与同步服务；Modeling worktree 作为独立路线。没有在这些目录写入或切换分支。本次在 `10_Codex/worktrees/FocusAnchor-Watch-UX-V3.2` 从已审查源码快照建立独立分支，基线提交 `26da259`；工作成果尚未合并。合并前需重新对照并行路线的 Wear 同名文件。

## 验收证据与限制

- Node 状态/队列测试：9 项通过，新增覆盖 P1 八种交互形象与 P3 三种用户状态素材映射；其他覆盖无任务/歧义、指定 actionId、开始/暂停/继续/完成事件、六监测状态及过期数据、闪念本地/等待/ACK/失败、失败后恢复与 ACK 队列语义。
- HarmonyOS Wear HAP：`assembleHap` 构建成功；输出为 unsigned HAP。未改签名配置。
- 隔离手表模拟器：初次打开确认 V3.2 已运行并显示真实空任务态；之后补充的大幅 P1/P2/P3 页面完成编译，但重建期间模拟器断开。用户用 Escape 中断 Windows UI 自动化后，本轮没有继续启动/重装，因此新图未做模拟器截图验收。初次系统小艺同意流程与麦克风允许/拒绝页面分别在隔离模拟器上走过。没有注入真实语音，所以 ASR 转写成功未验证。
- 闪念跨设备同步：未连接真实手机 ACK；模拟器仅能证明手表本地队列和 pending 展示，未声称已同步。同步失败/重试以状态函数和队列测试验证，未对生产手机 KV 故障做端到端注入。
- 开始/暂停/继续/完成：事件队列单元测试验证；无权威 `currentActionId` 的模拟器 bundle 未作为真实业务验收。
- 未完成真机验证；圆屏证据限于隔离模拟器。取消路径由编辑页按钮清空草稿实现，未做独立的输入法语音取消真机验收。

## 与协同路线的边界

任何对主 worktree、V3.1 或 Modeling 的 cherry-pick/合并均未执行。负责人可先在此 worktree 审阅 UI 和契约，再协调是否合并及如何解决同文件冲突。
