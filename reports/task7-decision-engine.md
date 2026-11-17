# Task 7 — HarmonyOS G0 隔离门控原型

> 2026-11-14 设备状态复核：通过 `D:/Tools/DevEco26/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe list targets` 得到 `[Empty]`。下文两个模拟器 `CONNECTED` 是 2026-11-03 的历史观察；当前模拟器运行仍 `NOT_RUN`。建模 HAP 与 UI/UX HAP 共用 bundleName，未覆盖后者。

日期：2026-11-01；分支：`codex/modeling-task0`。验收：**PASS（隔离源码、单测与 unsigned HAP 编译）/ BLOCKED（共享契约与真实 App 集成）**。

## 文件级影响与接口缺口

| 需求 | 新文件/改动 | 实际边界 |
|---|---|---|
| 确定性 G0 | `entry/src/main/ets/modeling/DecisionEngine.ts` | 纯函数。DND、主动许可、当次许可、15 分钟实验冷却、运动/未知活动、信号质量、OOD/不确定性、近期拒绝和候选时效逐项否决；不发送通知。 |
| 回放网络 | `entry/src/main/ets/modeling/ReplayClient.ets` | 只读服务合成 fixture，再请求 M2 候选；超时/错误返回 null。没有读取 AppState、真实传感器、任务或用户资料。采用已有 `ohos.permission.INTERNET`，未修改权限。HTTP API 用法参考[华为官方文档](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/network-kit-faq-0003)。 |
| 调试页 | `entry/src/main/ets/pages/ModelingReplayDebug.ets`、`entry/src/main/resources/base/profile/main_pages.json` | 独立路由，未在现有 Index/Settings/Focus UI 添加入口；默认 `allow_proactive_prompt=false`、未知活动/信号，展示门控结果，不调用 Agent/Workflow/ReminderService。 |
| 单测 | `tests/decision_engine.test.mjs` | Node 运行同一纯 TypeScript 门控模块。 |

现有 `PrivacySettings` 没有主动提示许可字段，不能把 `allowAnalytics` 等设置替代 `allow_proactive_prompt`。候选 Schema `0.1-replay` 仍是实验接口；`docs/changes/CHANGE-MODEL-001.md` 为 `PROPOSED`，尚未审批。当前 G0 的 `ALLOW_ASK/ALLOW_SUGGEST` 只表示纯函数通过，`executed=false` 且没有任何执行适配器。服务超时/离线、模型拒判和坏信号产生 `MANUAL_ONLY`；既有手动 Agent 路径没有被改动或由此函数调用。

## 验证

```powershell
node --test tests/decision_engine.test.mjs
$env:DEVECO_SDK_HOME='D:\Tools\DevEco26\DevEco Studio\sdk'
& 'D:\Tools\DevEco26\DevEco Studio\tools\node\node.exe' 'D:\Tools\DevEco26\DevEco Studio\tools\hvigor\bin\hvigorw.js' assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
& 'D:\Tools\DevEco26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
```

G0 单测 6/6 通过，覆盖高分不能绕过 `allow_proactive_prompt=false`（包括用户主动请求同时存在时）、SUGGEST 当次许可、DND、运动、坏信号、OOD、uncertainty、冷却、近期拒绝、过期候选、版本错误、模型无动作与服务故障。第一次 ArkTS 编译因 `ReplayClient.ets` 嵌套对象字面量类型失败；改为显式接口后最新构建 **BUILD SUCCESSFUL in 43 s 927 ms**。生成 `entry/build/default/outputs/default/entry-default-unsigned.hap`。项目没有签名配置，构建日志明确跳过签名；未修改签名。

`hdc list targets` 显示两个已启动模拟器目标 `127.0.0.1:5555` 与 `127.0.0.1:5557`；进程参数显示 Pura 90 Pro 手机和 Huawei_Wearable 手表模拟器。用户正在 UI/UX 工作树调整并已安装该路线 HAP；两分支 `bundleName` 均为 `com.focusanchor.focuxanchor`，为避免覆盖，**没有把本建模分支 HAP 安装到设备**。因此调试页视觉、网络请求、端侧 G0 行为均为 `NOT_RUN`，用户当前已安装的 HAP 不能作为本分支验证证据。

2026-11-03 复核修正：合成 fixture 仍保存 `timestamp_ms=0`，但 `ReplayClient` 发起本次合成请求时写入 `Date.now()`；调试页 G0 使用设备当前时钟，而非候选时间戳作为 `now_ms`。这样 G0 过期判断不再被调试页的时钟输入短路。服务测试确认回包保留请求时间戳；编译再次 **BUILD SUCCESSFUL in 41 s 197 ms**，G0 Node 单测 6/6、Python 自动化测试 8/8。端侧运行仍未执行。

## 风险与待办

- 实验冷却 15 分钟、候选最大年龄 2 分钟、uncertainty 上限 0.5 与 1–99 分位 OOD 为保守原型参数，尚未作为产品阈值获批。
- `ReplayClient` 只允许 HTTPS 或本机 `127.0.0.1` 地址；模拟器到宿主机的网络地址、TLS、错误重试与 UI 展示未联调。
- `allow_proactive_prompt`、DND、拒绝记录和上次介入时间的真实状态源尚未批准；这份调试页只使用默认拒绝的合成状态。不得把本页或 `ALLOW_*` 结果接入现有提醒/Agent。
- Task 7 的真实端侧验证需在 UI/UX 路线不被覆盖的独立模拟器或另设 bundle 标识的调试包中进行；改 bundleName 属配置变更，未在本轮擅自实施。共享契约审批后才可设计生产接入。

编译：**PASS（未签名 entry HAP）**；自动化测试：**PASS（6 项 Node G0 单测；另有 8 项 Python 测试）**；手机模拟器：**CONNECTED, MODELING HAP NOT_INSTALLED/NOT_RUN**；手表模拟器：**CONNECTED, MODELING HAP NOT_INSTALLED/NOT_RUN**；真机：**NOT_RUN**。
