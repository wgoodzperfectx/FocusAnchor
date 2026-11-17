# Merge readiness（2026-11-17）

当前集成候选：`codex/integration-20261116`。以下状态基于本地 worktree，不代表 GitHub 已上传。

| 路线 | 当前判断 | 原因与下一步 |
|---|---|---|
| Integration | 本地候选 | Watch V3.3、Skill、离线 AgentArts 解析/后端边界和 README 已提交；本轮需复跑测试与构建后再作为协作基线 |
| Phone UX V3.1 | HOLD | 脏工作树；与 Workflow 107 个同路径脏文件、15 个内容不同；负责人查看效果前不合并 |
| Workflow V2.1 | SPLIT-COMMIT | 脏工作树含签名口令的未提交配置；只提交已分类的非敏感模块，剩余保留 |
| Watch V3.2 | HISTORICAL | 保留历史分支，上传前检查对象安全 |
| Watch V3.3 | 已纳入 Integration | 保留独立分支供审查，上传前检查对象安全 |
| Watch V3.4 | EXPERIMENTAL | 未完成交互实验，不提升为正式手表基线 |
| Modeling | EXPERIMENTAL | 研究资产可独立分享；WESAD→NURSE 泛化 FAIL，不进入生产主动触达 |
| Modeling Portability Check | ARCHIVE CANDIDATE | detached HEAD 已有恢复分支，8 个未提交文件已备份；先分类再提交 |

GitHub `github` Remote 已配置为 `https://github.com/wgoodzperfectx/FocusAnchor.git`，Gitee `origin` 保留。仓库当前为 Public；上传前须完成公开发布所需的敏感信息与素材权利审查。上传分支不等于合并或稳定验收。`8_Drive` 独立副本及 `7_Key`、`9_Dataset` 不参与。
