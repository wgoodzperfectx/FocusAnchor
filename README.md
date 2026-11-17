# 焦点锚 FocusAnchor

> 面向神经多样性（neurodiversity）友好的专注伙伴 —— 结合「心率感知」与「学习任务管理」的 HarmonyOS 专注辅助应用。

**FocusAnchor** 是一款基于 HarmonyOS（ArkTS / ArkUI）的双端应用，包含：

- **手机端 / 平板端（`entry` 模块）**：完整的功能入口 —— 专注模式、学习任务管理、语音交互、悬浮球、设置与本地加密存储。
- **手表端（`wear` 模块）**：圆形表盘上的轻量体验 —— 查看 / 编辑 / 完成任务，并通过分布式数据同步与手机实时互通。

---

## 一、软件架构

```
┌─────────────────────────────────────────────────────────────┐
│                     HarmonyOS 应用工程                         │
├──────────────────────────┬──────────────────────────────────┤
│  entry 模块（branch1）     │  wear 模块（branch2）              │
│  deviceTypes: phone/tablet│  deviceTypes: wearable            │
│  EntryAbility            │  WearAbility                       │
├──────────────────────────┴──────────────────────────────────┤
│  手机端分层                                                    │
│  pages/       Index · AppTabs · FocusPage · SettingsPage      │
│  components/  FloatBall（悬浮球）                              │
│  services/    AppState · Storage · WatchSync · XiaoyiBridge    │
│               Reminder · Domain(心率/建议) · TaskFile           │
│  models/      AppTypes（数据模型与业务规则）                    │
│  common/      LocaleHelper（中英双语）                         │
├──────────────────────────────────────────────────────────────┤
│  跨端能力：分布式 KV（手机↔手表任务/语言同步）                   │
│  本地安全：AES-256-CBC 加密存储 · 语音：CoreSpeechKit ASR        │
└──────────────────────────────────────────────────────────────┘
```

- **应用包名**：`com.focusanchor.focuxanchor`
- **版本**：`1.0.0`（versionCode `1000000`）
- **SDK**：HarmonyOS API `26.0.0`

---

## 二、功能特性

### 手机端 / 平板端（entry）

| 模块 | 功能 |
| --- | --- |
| 首页概览 | 显示当前心率（BPM）、专注状态等级、系统时间；一键进入「焦点」页；手动「提醒未完成」 |
| 专注模式 | 心率圆环按专注等级变色（绿→黄→橙→红），白盘缩放进入动画 + 波浪动画 |
| 学习任务管理 | 任务新增 / 编辑 / 清除；优先级（高 / 中 / 低）；Deadline 解析与自动提级；学习方式；语音输入 |
| 小艺语音 | 麦克风权限申请、ASR 语音转文字（中 / 英回退）、语音命令解析、语音快速建任务 |
| 悬浮球 | 可拖拽 + 贴边吸附；单击快捷菜单（焦点 / 设置 / 添加任务）；双击语音面板 |
| 个性化建议 | 基于专注状态与任务生成建议；学习效率指数（0–100） |
| 提醒 | 系统通知提醒未完成任务；每 15 分钟周期检查 + 手动立即提醒 |
| 设置 | 中 / 英切换；个人资料（昵称、年龄、头像预设 / 相册选图）；隐私开关；心率区间；PIN 锁定 |
| 本地安全 | 任务与心率历史使用 AES-256-CBC 加密落盘（随机 IV + SHA256 派生密钥） |

### 手表端（wear）

| 模块 | 功能 |
| --- | --- |
| 圆形表盘布局 | 针对圆形屏幕的安全区适配（Swiper 双页 + 翻页指示点） |
| 任务管理 | 任务列表、新建 / 编辑 / 完成 / 删除；优先级循环选择；Deadline 天数（1 / 3 / 7 天） |
| 专注模式 | 心率圆环 + 波浪动画 + 白盘进入动画（圆表盘裁剪） |
| 设置 | 语言切换（中 / 英） |
| 数据同步 | 通过分布式 KV 与手机同步任务与语言（last-write-wins） |

---

## 三、目录结构

```
pig-master/
├── AppScope/                    # 应用级配置（包名、版本、图标）
├── entry/                       # branch1：手机端 / 平板端
│   └── src/main/ets/
│       ├── common/LocaleHelper.ets      # 中英双语
│       ├── components/FloatBall.ets     # 悬浮球
│       ├── entryability/EntryAbility.ets# 启动入口（先引导再加载页面）
│       ├── models/AppTypes.ets          # 数据模型 + 业务规则
│       ├── pages/                        # Index / AppTabs / FocusPage / SettingsPage
│       └── services/                     # AppState / Storage / WatchSync / XiaoyiBridge ...
├── wear/                        # branch2：手表端
│   └── src/main/ets/
│       ├── entryability/WearAbility.ets  # 手表启动入口
│       └── pages/                        # Index / FocusPage / SettingsPage
├── build-profile.json5          # 多模块构建配置
├── oh-package.json5
└── README.md
```

---

## 四、环境要求与构建

1. 安装 **DevEco Studio** 26.0.0（支持 HarmonyOS API 26.0.0）。
2. 克隆 / 打开本工程，等待依赖同步完成。
3. 在 `File → Project Structure → Signing Configs` 中配置签名（真机运行必需；模拟器可跳过部分）。
4. 选择目标设备：
   - 运行 `entry` → 手机 / 平板；
   - 运行 `wear` → 手表模拟器或真机。
5. 点击 **Run** 编译并安装。

> 手机端与手表端需登录同一华为账号、开启分布式能力，才能触发任务 / 语言同步。

---

## 五、权限说明

| 权限 | 用途 |
| --- | --- |
| `ohos.permission.MICROPHONE` | 小艺语音转文字输入 |
| `ohos.permission.READ_IMAGEVIDEO` | 相册选择头像 |
| `ohos.permission.DISTRIBUTED_DATASYNC` | 手机 ↔ 手表任务 / 语言同步 |
| `ohos.permission.INTERNET` | 在线语音识别等网络能力 |
| `ohos.permission.VIBRATE` | 心率告警震动 |

---

## 六、当前实现状态（诚实说明）

| 能力 | 现状 |
| --- | --- |
| 心率数据 | ⚠️ 目前为**模拟随机漂移**（60–120 BPM），尚未接入真实传感器 / 手表健康数据 |
| 小艺智能体建议 | ⚠️ 当前走**本地硬编码文案**，尚未接入真实 AI / LLM 接口 |
| PIN 锁定 | ⚠️ 已提供开关与存储，但**未在启动时做真正拦截**，加密强度待加强 |
| 手机 ↔ 手表同步 | ✅ 分布式 KV 已打通（任务 + 语言） |
| 本地加密存储 | ✅ AES-256-CBC 已实现 |

---

## 七、参与贡献

1. Fork 本仓库
2. 新建 `Feat_xxx` 分支
3. 提交代码
4. 新建 Pull Request

---

## License

见 [LICENSE](./LICENSE)。
