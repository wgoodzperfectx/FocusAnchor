# Task 0 真实文件与环境清单

审计日期：2026-10-29；worktree：`<LOCAL_PROJECT_ROOT>/10_Codex/worktrees/FocusAnchor-Modeling`；分支：`codex/modeling-task0`；起点提交：`81d3a9265369b0481abca661d910434f2fc336ab`。

## 已提交基线中的文件

以下路径均相对于本 worktree，已从真实文件读取；仅为 E0 静态审计。

| 路径 | 主要符号/作用 |
|---|---|
| `entry/src/main/ets/models/AppTypes.ets` | `StudyTask`、`HeartRateSnapshot`、`PrivacySettings`、`focusLevelFromBpm` |
| `entry/src/main/ets/services/AppState.ets` | `bootstrap`、任务与心率状态、定时提醒初始化 |
| `entry/src/main/ets/services/DomainServices.ets` | `HeartRateService` 模拟采样与规则分析、`AdviceService` |
| `entry/src/main/ets/services/XiaoyiBridge.ets` | `startHeartRateStream`、`askAdvice` 本地 fallback、语音入口 |
| `entry/src/main/ets/services/ReminderService.ets` | 15 分钟检查、系统通知 |
| `entry/src/main/ets/services/TaskFileService.ets` | `tasks.json` 读写 |
| `entry/src/main/ets/services/StorageService.ets` | preferences 与加密 bundle |
| `entry/src/main/ets/services/WatchSyncService.ets` | 分布式 KV 同步接口 |
| `entry/src/main/ets/pages/FocusPage.ets` | 现有模拟 BPM 页面路径 |
| `entry/src/main/ets/pages/AppTabs.ets` | 任务 UI 与手动请求建议 |
| `entry/src/main/ets/entryability/EntryAbility.ets` | 手机入口 |
| `wear/src/main/ets/entryability/WearAbility.ets` | 手表入口 |
| `entry/src/main/module.json5` | 手机权限含 INTERNET；未见 Health Kit 权限 |
| `wear/src/main/module.json5` | 手表声明 DISTRIBUTED_DATASYNC；未见 INTERNET/Health Kit 权限 |
| `oh-package.json5`、`build-profile.json5` | HarmonyOS 项目声明；签名材料未改动，审计文档不记录密钥值 |

已提交基线未找到 `ml/` starter、Python `requirements.txt`/`pyproject.toml`、M1/M2 服务、FastAPI 端点或端侧 HTTP client。否定结论仅限该提交和本轮搜索范围。

## 并行工作区文件（未提交）

绝对根路径：`<LOCAL_PROJECT_ROOT>/Huang-A/pig-master`，分支 `codex/workflow-v21`，审计时为脏工作区。

| 路径 | 观察 |
|---|---|
| `entry/src/main/ets/services/WorkflowV21Contracts.ts` | 2.1.0 `ContextFeatures`、`InterventionDecision`、`WorkflowDeps` |
| `entry/src/main/ets/services/WorkflowV21Mocks.ts` | Mock M1/M2 与设备提供者 |
| `entry/src/main/ets/services/WorkflowV21AppService.ets` | 本地 Mock 路径、设备 offline |
| `entry/src/main/ets/services/WorkflowV21Router.ts` | 工作流门控与调用顺序 |
| `entry/src/main/ets/services/FocusConsent.ts` | `resolveFocusConsent` |

这些文件没有复制到建模 worktree，不构成可复现依赖。UI/UX worktree：`<LOCAL_PROJECT_ROOT>/10_Codex/worktrees/FocusAnchor-UX-V3.1`，`codex/ux-v3-1`，同样有未提交改动。

## 环境及数据观察

- Windows PowerShell；Python `3.14.2`；Node `v24.13.0`；Java 命令可见。`hvigor`、`hdc` 命令在 PATH 中未找到。`<LOCAL_USER_HOME>/AppData/Local/Huawei/Sdk` 存在，但本轮未验证 DevEco Studio 安装、SDK 组件或构建可用性。
- D 盘审计时剩余约 345.8 GB（`Get-PSDrive D`），足够不等于训练运行已经完成。
- 用户数据目录 `<LOCAL_PROJECT_ROOT>/9_Dataset`：`WESAD.zip` 2,249,444,501 字节，SHA256 `5E15D2606ADF16D819BA535C1786D92E94BAE5FF5392F7AE01FB63F9938FD71C`；解压目录仅观察到 `S10`、`S11`（S11 当时未见文件）。未执行 ZIP 完整性、参与者数量、许可或数据质量检查；NURSE、Mobile Phone Use、K-EmoPhone 未在该目录观察到。Task 1 需继续核对数据来源及访问状态。
- Task 0 没有下载数据、加载 `.pkl`、执行预处理或训练。

## 执行命令与验收证据

执行过：`git status --short --branch`、`git worktree list --porcelain`、`git log -1`、`rg --files`、`rg -n`、`Get-Content`、`Get-ChildItem`、`Get-Command`、`python --version`、`node --version`、`Get-PSDrive D`、`Get-FileHash 9_Dataset/WESAD.zip -Algorithm SHA256`、`pypdf.PdfReader(...).extract_text()`。首次在项目外层运行 Git 时命中 `D:/` 仓库，已纠正到 `Huang-A/pig-master`。一次 `rg` 使用 Windows 不支持的通配路径而失败，随后改为目录限定搜索；这不影响最终静态结论。

编译：**NOT_RUN**。自动化测试：**NOT_RUN**。模拟器：**NOT_RUN**。真机：**NOT_RUN**。模型实验与指标：**NOT_RUN**。Task 0 验收：**PASS（静态审计 E0）**；运行兼容性与数据完整性未验证，列为下一阶段依赖。
