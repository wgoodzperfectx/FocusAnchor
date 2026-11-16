# GitHub 发布前检查（2026-11-16）

**状态：BLOCKED。** 当前 `origin` 为 Gitee `master`，未配置 GitHub Remote，也未核验 GitHub 仓库地址、可见性或默认分支。未创建仓库、Push、Release 或更改远端。

| 检查 | 结果 |
|---|---|
| README / Demo | 本分支已新增产品 README、本地 Demo 和能力矩阵；需在提交前重跑文档中的命令 |
| 本地测试 | 集成树之前 Node 19/19、素材 9 项通过；文档提交后复跑 |
| 构建/设备 | NOT_RUN；需 DevEco 构建、模拟器与设备日志 |
| 凭证/签名 | 已跟踪文件名未见 `.p12`、`.p7b`、`.jks`、`.env`；定向扫描未见常见私钥/API Key 模式；需发布前完整安全审查 |
| 大文件 | 已跟踪文件未发现超过 10 MB；录屏 MP4 存在于 `docs/evidence/watch-v3.3/`，需确认发布许可和隐私 |
| 数据/模型 | 本分支未跟踪原始数据集或模型权重；项目根 `9_Dataset/` 不应自动纳入公开仓库 |
| 许可 | 根 `LICENSE` 为 GPL-2.0；原有代码与第三方素材、录屏、知识资产权利尚未逐项确认 |
| Git LFS | 当前大文件未超 10 MB，LFS 使用及托管配额未核验 |
| 可复现性 | 本地 Node Demo 可运行；完整 App/AgentArts/双端 Demo 尚未建立 |

建议在权利与敏感内容审查通过后，先从 `codex/integration-20261116` 建立受审查的 GitHub 候选分支，再单独决定远端创建与 Push。当前不建议公开发布。
