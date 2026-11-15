# Watch UX V3.4 — WATCH 5 下键快捷记闪念审查（2026-11-15）

## 基线与边界

- 独立工作树：`10_Codex/worktrees/FocusAnchor-Watch-UX-V3.4`，分支 `codex/watch-ux-v3-4`，从已提交的 V3.3 `4a2fbd4` 分出。主工作树与 `codex/ux-v3-1` 均有未提交改动，本路线不写入它们。
- 按总体章程和项目 `AGENTS.md`，只考虑 Wear UI、导航和只读输入适配。同步/ACK、手机任务状态、Agent、心率算法、权限和签名配置均不改。
- 目标真机是 **HUAWEI WATCH 5**；当前没有真机。可运行环境是 DevEco 的 466×466 `MCHEMU-AL00CN` 通用穿戴模拟器，HarmonyOS API 26；项目目标 API 24。模拟器身份不能等同 WATCH 5。

## 官方资料与可得结论

| 操作 | WATCH 5 官方行为 | 本轮可用性 |
| --- | --- | --- |
| 上键（旋转表冠）单击 | 非表盘界面返回表盘；双击最近任务；长按电源/重启 | 系统保留，不能映射为闪念。`onDigitalCrown` 只处理旋转。 |
| 下键单击 | 表盘上打开快捷功能页，可在“设置 > 按键设置 > 单击下按键”选择目标应用 | 可由用户在真机配置启动 FocusAnchor；官方说明未证明能指定应用内闪念页。 |
| 下键双击/长按 | 钱包 / 语音助手 | 系统保留，不拦截。 |
| 智感窗轻压/轻触 | 微体检、健康检测等设备功能 | 不作为闪念快捷键。 |
| 应用前台键事件 | 获焦 ArkUI 组件可通过 `onKeyEvent` 接收键事件 | API 可用；尚无 WATCH 5 下键单击在 FocusAnchor 前台的实际 `keyCode` 和分发证据。 |

来源：[WATCH 5 外观](https://consumer.huawei.com/cn/support/content/zh-cn16047936/)、[WATCH 5 按键与手势](https://consumer.huawei.com/cn/support/content/zh-cn16047945/)、[ArkUI KeyEvent](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-events-key/)、[表冠事件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-events-crown/)、[模拟器能力](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-more-features/)。SDK 的 `KEYCODE_DIV=3220` 注释为“智能手表左键”，但不能据此认定它就是 WATCH 5 下键。`inputConsumer` 全局热键接口不支持 wearable，不能作为替代。

## 源码差距与接口缺口

- `wear/src/main/ets/pages/Index.ets`：主页与闪念是 Swiper 两页。触控“记闪念”进入闪念页，再点“说一句”，`openFlashInput()` 将 `flashEditing` 置真并聚焦 `flashDraftInput`；当前没有 `onKeyEvent`。系统输入法打开后还需点麦克风才进入语音模式。
- `wear/src/main/ets/entryability/WearAbility.ets`：仅加载 `pages/Index`；无应用内快捷页 Want 参数，也无快捷键来源标识。
- 输入法没有向应用暴露“开始/停止听写”、权限结果或取消的可靠回调。不得以打开输入法冒充开始录音。
- 尚缺 WATCH 5 真机前台下键单击事件的分发、`keyCode`、焦点行为；通用模拟器 CLI 没有下键单击指令。也缺表盘下键选择应用后传给目标 Ability 的可区分 Want。基于这些缺口，本轮不绑定未经证实的键码，也不添加第二条语音/ASR 链路。

## 文件级实施方案（条件满足后）

1. `wear/src/main/ets/pages/Index.ets`：在前台页面的获焦节点接入只读 `onKeyEvent`，仅识别**真机确认**的下键短按且无输入框/系统弹层占焦时，复用现有 `openFlashInput()`；返回和系统保留键透传。普通触控路径保持可用。
2. `wear/src/main/ets/components/HardwareShortcutAdapter.ets`（仅当观测到稳定事件后新建）：封装经验证的设备按键映射、按下/抬起去重与前台条件，不连接任何同步或推断服务。未知设备不触发。
3. `wear/src/test/...`：纯逻辑验证短按触发一次、长按/双击不触发、输入中不重复打开；模拟器 UI 验证现有触控入口与返回。
4. 本文与 `evidence/watch-v3.4/`：记录官方依据、模拟器/真机证据与剩余项。

## 当前模拟器记录

第一次连接的是 `FocusAnchor_Modeling_Phone`（`phone`，127.0.0.1:5555），Wear HAP 安装因设备类型不匹配而被拒。随后启动已存在的 `FocusAnchor_Watch_UX_V32`（`wearable`，127.0.0.1:5557），V3.3 Wear HAP 安装成功，`WearAbility` 启动成功。首页截图为 [`baseline-home-empty.png`](../evidence/watch-v3.4/baseline-home-empty.png)。触控“记闪念”可到闪念页，点“说一句”打开系统输入法，再点输入法麦克风进入语音界面；语音界面截图为 [`baseline-ime-voice.png`](../evidence/watch-v3.4/baseline-ime-voice.png)。本次没有语音识别成功、授权、保存或 ACK 的新端到端证据。

V3.4 独立工作树以 `DEVECO_SDK_HOME=D:\Tools\DevEco26\DevEco Studio\sdk` 执行 `hvigorw.bat assembleHap -p product=default -p buildMode=debug --no-daemon`，68 个任务全部完成，构建成功（既有 ArkTS 警告、未配置签名）。该工作树的 Wear HAP 也已安装到上述穿戴模拟器。源码与 V3.3 基线相同，尚无 V3.4 生产代码改动。自动化测试本轮未运行，真机结果无。

## V3.4 验收状态

| 用例 | 状态与证据 |
| --- | --- |
| T01 上键单击保持系统返回 | 官方行为已确认；模拟器按键交互未验证。 |
| T02 下键单击打开闪念 | **未验证/未实现**；模拟器无下键事件注入能力，真机缺席。 |
| T03 下键双击/长按保持系统功能 | 官方行为已确认；真机未验证。 |
| T04 前台焦点与输入框去重 | 待 T02 可观测后实现。 |
| T05 触控闪念入口 | 模拟器已验证“记闪念”→“说一句”→系统输入法。 |
| T06 语音开始与取消 | 模拟器已到系统语音界面；识别/取消回调未验证。 |
| T07 权限首次授权/拒绝 | 本轮未验证。 |
| T08 本地保存与待同步 | V3.3 页面显示既有“已保存在手表 · 等待同步”；本轮未重新写入或验证 ACK。 |
| T09 同步失败/恢复 | 本轮未验证；不改传输和 ACK。 |
| T10 圆屏/伙伴状态/返回 | 466×466 首页及输入界面截图已检查；硬件返回和真机裁切未验证。 |

**当前判断：** WATCH 5 下键可在系统设置中配置为启动应用，但“单击后直达 FocusAnchor 语音录入”不能由现有官方资料和通用模拟器证实。保留触控入口，待可观测的前台下键事件或官方应用内快捷启动契约后接入。不可将 T02 标记通过。
