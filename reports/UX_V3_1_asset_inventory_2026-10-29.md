# UX V3.1 小步伙伴资源盘点

根目录：`entry/src/main/resources/base/media/`；手表模块中存在同名副本。本轮只读检查尺寸与 alpha，未修改正式 PNG。抽查 `fa_monitor_reading` 与 `status_ready` 视觉：角色黑炭轮廓、眼睛和绿色脚部均可辨；其余素材沿用此前 V3.1 逐张目视审查记录。

## 9 张正式状态图

以下均为 **512×512、alpha 全 255、不透明近白背景**。在暖浅页面直接放大展示会形成明显白色方块，故当前 Home/Step/Focus 主视觉暂用透明 `status_*`。正式图保留给设备/陪伴状态的后续视觉适配，不据图名推断真实设备或生理状态。

| 文件 | 设计用途 | 本轮状态 |
|---|---|---|
| `fa_monitor_connecting.png` | 连接中 | 待设备状态来源与透明底版本 |
| `fa_monitor_reading.png` | 读取中 | 待设备状态来源与透明底版本 |
| `fa_monitor_monitoring.png` | 监测中 | 待设备状态来源与透明底版本 |
| `fa_monitor_signal_unstable.png` | 信号不稳 | 待设备状态来源与透明底版本 |
| `fa_monitor_reconnecting.png` | 等待重连 | 待设备状态来源与透明底版本 |
| `fa_monitor_stopped.png` | 已停止 | 待设备状态来源与透明底版本 |
| `fa_companion_stable.png` | 稳定陪伴 | 待可信 M1 状态来源与透明底版本 |
| `fa_companion_fluctuating.png` | 状态波动 | 待可信 M1 状态来源与透明底版本 |
| `fa_companion_support_requested.png` | 请求支持 | 待可信触发来源与透明底版本 |

## 8 张引导图

以下均为 **320×240、带 alpha 透明区域**。当前由 `CompanionVisualService.ets` 映射，并由 `CompanionView.ets` 统一展示。

| 文件 | 完全透明像素/总像素 | 当前用途 |
|---|---:|---|
| `status_ready.png` | 44,610 / 76,800 | 空、未知、错误中性态 |
| `status_listening.png` | 44,550 / 76,800 | 语音/监听视觉预留 |
| `status_breaking_down.png` | 51,091 / 76,800 | 真实请求等待视觉预留 |
| `status_awaiting_confirmation.png` | 43,567 / 76,800 | 澄清状态预留 |
| `status_first_step.png` | 45,107 / 76,800 | 第一小步/已确认 |
| `status_in_progress.png` | 46,904 / 76,800 | Action 进行中 |
| `status_paused.png` | 44,608 / 76,800 | FocusSession 暂停 |
| `status_step_complete.png` | 44,611 / 76,800 | Action 完成 |

## 素材缺口

`status_*` 的眼睛为透明孔洞，显示时继承页面背景色；暖浅背景下并非纯白。若最终规范要求始终纯白眼睛，需要设计源文件提供眼睛为白色、外轮廓透明的新版本，并逐张核验绿色脚部与边缘。当前不对正式资源做颜色阈值抠图，也不覆盖原文件。
