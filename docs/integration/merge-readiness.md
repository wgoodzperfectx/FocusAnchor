# Merge readiness（2026-11-17）

当前集成候选：`codex/integration-20261116`。该分支、Watch V3.2/V3.3/V3.4、Phone UX WIP、Workflow WIP 和 Modeling 脱敏快照已上传 GitHub。GitHub `main` 的初始历史已接入集成分支，PR Compare 可用。

| 路线 | 当前判断 | 原因与下一步 |
|---|---|---|
| Integration | 候选 | Watch V3.3、Skill、离线 AgentArts 解析/后端边界和 README 已提交；本轮 Node 19/19、素材 9 项、entry/wear 无签名构建通过 |
| Phone UX V3.1 | WIP / HOLD | 已分模块提交并上传；本地签名配置未提交；Node 57/59；负责人查看效果前不合并 |
| Workflow V2.1 | WIP / HOLD | 已分模块提交并上传；含口令签名配置、原始日志和截图留本地；Node 204/204，平台实测仍待验证 |
| Watch V3.2 | HISTORICAL | 保留历史分支，已上传 |
| Watch V3.3 | 已纳入 Integration | 保留独立分支供审查，上传前检查对象安全 |
| Watch V3.4 | EXPERIMENTAL | 未完成交互实验，不提升为正式手表基线 |
| Modeling | EXPERIMENTAL | 脱敏快照 `codex/modeling-public-20261117` 已上传；原历史因本机路径仅本地保留；WESAD→NURSE 泛化 FAIL，不进入生产主动触达 |
| Modeling Portability Check | LOCAL ARCHIVE | detached HEAD 已转命名恢复分支，8 个结果文件已提交；公开快照包含结果，原历史不上传 |

GitHub `github` Remote 已配置为 `https://github.com/wgoodzperfectx/FocusAnchor.git`，Gitee `origin` 保留。仓库当前为 Public；上传前须完成公开发布所需的敏感信息与素材权利审查。上传分支不等于合并或稳定验收。`8_Drive` 独立副本及 `7_Key`、`9_Dataset` 不参与。
