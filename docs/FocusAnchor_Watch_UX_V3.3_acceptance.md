# Watch UX V3.3 验收记录

基线：`codex/watch-ux-v3-3`，独立 worktree `10_Codex/worktrees/FocusAnchor-Watch-UX-V3.3`。本分支只改 Wear 页面、UI 状态投影、组件、视觉资源和验收资料。主工作树与 UX V3.1 的未提交改动未合并、未覆盖。

## 页面和状态来源

| UI | 输入来源 | 可显示内容 | 当前缺口 |
|---|---|---|---|
| 当前一步 | `tasks_sync` 的手机任务投影、`currentActionId`；本地待 ACK 操作队列 | 唯一 Action、开始/暂停/继续；没有 Action 时真实空状态 | 手机未稳定提供明确的 `currentActionId`；不能让手表自行创建权威任务 |
| 闪念 | 系统输入法文本；Wear preferences 本地闪念队列；KV 传输与 `flash_acks_sync` | 本地保存、待同步、ACK 确认、失败与重试 | 系统输入法 ASR 开始/停止/权限回调未暴露给页面，故页面不假装进入 LISTENING；小艺接口留给后续 |
| 心率 | 只读 `WearMonitorSnapshot` 路由参数，60 秒新鲜度门槛 | 六种已知状态对应 P2；未知时中性图、`-- bpm`、无数据 | 当前没有可信监测快照生产者，也没有有效 bpm/权限/最后读取时间契约 |
| 陪伴 P3 | 可选的手机 `tasks_sync.companionState` | 仅收到 STABLE / FLUCTUATING / SUPPORT_REQUESTED 时映射正式资源 | 手机端尚未承诺可信的评估/授权来源；模拟器中不展示推断结果 |
| 语言/减少动效 | Wear 本地 preferences | 中英切换与 220ms 角色切换关闭开关 | 系统低功耗/Reduced Motion 自动读取尚无平台适配接口 |

角色的视觉 ID 集中在 `WearUiState.ts`，资源映射在 `WearVisualService.ets`。P1 八张交互图沿用已有透明资源；P2 六张、P3 三张由 `scripts/prepare_wear_alpha.py` 从正式原图清除仅与外边界连通的近白底，裁掉透明边缘，保留深色轮廓、白眼和绿脚。原图不变；`tests/test_wear_v33_assets.py` 验证九张输出均有透明像素、深色身体、白色眼睛/符号和绿色脚。当前素材没有独立眼睛、绿脚、状态符号层，因此 Motion B 需设计补件。

Motion A：`WearCompanion` 只在 `visualId` 改变时做 220ms opacity 0.76→1、scale 0.98→1 的一次过渡；减少动态效果开启时立即切换。没有随机轮播、视频或动画驱动的业务状态。

模拟器录屏：`evidence/watch-v3.3/watch-v33-walkthrough.mp4` 展示 A↔B 与 A→C→A；`evidence/watch-v3.3/watch-v33-settings.mp4` 展示 D 的滚动区域。均为设备帧缓冲录制，4 fps；动态转场的逐帧流畅度需在真机另测。

## T01–T14 证据矩阵

| 场景 | 本轮证据与结论 | 未验证 |
|---|---|---|
| T01 无任务 | 模拟器空状态截图 `evidence/watch-v3.3/home-empty-zh.jpeg`；自动化检查空/不完整/歧义投影无虚构步骤 | 手机真实空投影跨设备送达 |
| T02 READY Action | 自动化检查唯一 `actionId` 选择及 FIRST_STEP 映射 | 模拟器真实手机投影 |
| T03 ACTIVE→PAUSED→ACTIVE | 自动化检查 start/pause/resume 事件与主按钮映射；修复 `paused` 文案和角色 | 实际手机 ACK 往返 |
| T04 DONE 成功/失败 | 自动化检查 complete 事件；只有手机投影以相同 `currentActionId` 明确确认 completed 时才显示完成角色，未确认则维持等待/空状态 | 成功/拒绝 ACK 的模拟器实测；手机可能在完成后清除 `currentActionId`，需统一契约 |
| T05 录音/取消/权限拒绝 | 模拟器“说一句”直达系统输入法麦克风，截图 `evidence/watch-v3.3/system-voice-input.jpeg`；实测可启动语音界面、无语音识别失败后退出；取消返回闪念页 | 首次授权弹窗和拒绝路径；输入法没有状态回调 |
| T06 本地保存/待同步 | 自动化检查本地队列及 pending 文案 | 模拟器持久化后重启、真实手机链路 |
| T07 ACK | 自动化检查匹配 ACK 才从队列移除并显示“同步已确认” | 实际双端 ACK |
| T08 断连/信号差/未知 | 模拟器未知心率截图 `evidence/watch-v3.3/heart-unknown-zh.jpeg`，中性图和无数据；自动化检查过期快照失效 | 真实断连与信号异常事件 |
| T09 监测六图 | 自动化验证六种状态互异；九张透明资源验证通过 | 六状态设备事件驱动截图 |
| T10 陪伴三图 | 自动化验证三种正式 ID，未知回中性图 | 可信 M1/M2/授权事件生产者 |
| T11 多语言/圆屏 | 466×466 模拟器中英切换、首页/闪念/心率/设置目测；页面截图在 `evidence/watch-v3.3/` | 更小圆屏、真机字体比例与边缘手势 |
| T12 减少动态效果 | 设置页 `evidence/watch-v3.3/settings-zh-motion-on.jpeg` 中手动开启，开关传入角色组件，代码路径禁用过渡 | 系统低功耗自动联动 |
| T13 心率 More | 模拟器心率页仅有返回入口；源码无 More→语言路由 | 无 |
| T14 操作与返回 | 模拟器 A↔B、A→C→A、A→D→A、语音取消；编辑时 Save/Cancel 可见 | 真实端到端保存、同步、任务完成 |

## 验证命令

- `python tests/test_wear_v33_assets.py`：9 张资源通过。
- `node --test tests/wear-ux-v3-2.test.mjs`：10/10 通过。
- `hvigorw.bat assembleHap -p product=default -p buildMode=debug --no-daemon`：构建通过；未配置签名，模拟器可安装 unsigned HAP。

截图来自 HarmonyOS 466×466 模拟器的 `snapshot_display`，不是设计稿或真机证据。实际心率读数、权限拒绝、Action ACK、闪念 ACK 和小艺 ASR 回调均未验证。合并时重点核对主工作树/UX V3.1 的 `Index.ets`、`FocusPage.ets`、`WearUiState.ts` 与同步契约差异；本分支不直接覆盖其他路线。
