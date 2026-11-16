# FocusAnchor

FocusAnchor 是面向日常行动启动与中断后恢复的行动支持系统。用户主动请求可获得可修改的第一小步；获授权的情境事件先经过安全门控，再考虑是否提供低打扰建议。当前仓库是本地集成版本，尚非生产系统。

## 用户问题与创新

传统待办工具主要记录任务或定时提醒。本项目研究任务规划、用户确认、情境证据以及“不介入”的受控流程，面向难以启动任务或中断后难以恢复的用户；不提供医疗诊断或疗效保证。

## 系统架构

```text
Channel U 用户请求 → 安全检查 → Task Planner 候选 ─┐
Channel C 授权事件 → G0 → M1 → M2 候选 → G0 复检 ─┤
                                                 ↓
                    用户确认 → 主体 App 状态源 → 手机/卡片/手表投影
```

`G0` 是授权与安全硬约束；`M1` 给出情境证据，`M2` 给出可拒判的介入候选。Workflow 负责编排，主体 App 维护权威 Task/Action 状态。图示是设计职责，实际覆盖范围见[能力矩阵](docs/evidence/capability-status.md)及[总体章程](docs/architecture/FocusAnchor_Architecture_Charter_v0.1.md)。

## 功能状态与演示

本分支包含手表 V3.3 候选界面、状态/队列逻辑和后端 AgentArts 响应解析组件。后者仅通过合成响应测试，尚未完成真实平台调用或 App 注入。手机 V3.1、Workflow 大量未提交改动和 Modeling 研究保留在各自工作树。Watch V3.4 是未完成的人机交互实验。[手表截图和录屏](docs/evidence/watch-v3.3/)不证明真实跨端 ACK。

## Quick Start 与本地 Replay

需要 Node.js 24（本轮使用 v24.13.0）和 Python 3。在仓库根目录运行：

```powershell
node --test tests/*.test.mjs
python tests/test_wear_v33_assets.py
```

详见[本地 Demo](docs/demo/README.md)。`scripts/agentarts-runtime-client.mjs` 是后端边界，不应打包进 HarmonyOS 客户端。其测试使用合成输入，不发送真实平台请求。

## 测试与限制

本分支最近一次 Node 测试 19/19，通过 9 个透明手表素材检查；`entry` 和 `wear` 的 DevEco 26 SDK 构建均成功，产物未签名。手机原树全量 Node 测试 57/59，两项 Workflow 测试因缺少 `WorkflowV21Mocks.ts` 无法加载。模拟器、真机、AgentArts、卡片回写和双端 ACK 均无本分支本轮验收结果。参见[能力矩阵](docs/evidence/capability-status.md)与[路线图](docs/roadmap.md)。

## License 与 Credits

仓库当前有 [GPL-2.0 LICENSE](LICENSE)。公开发布前须核对原有代码、第三方图片/录屏、知识与数据的权利和许可；见[发布检查](docs/evidence/github-publication-check.md)。当前 Git Remote 仅指向 Gitee，尚无 GitHub Remote。
