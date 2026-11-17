# Contributing to FocusAnchor

1. 克隆经项目负责人确认的私有仓库，检出需要的专题分支；当前集成候选为 `codex/integration-20261116`。不要把 Gitee `origin/master` 当作自动合并目标。
2. 从最新集成基线创建 `codex/<topic>` 分支和独立 worktree。开始前阅读根目录 `AGENTS.md`、总体章程及适用 Task Spec，运行 `git status --short --branch`。
3. 在专题 worktree 实施并按模块暂存具体路径。提交前运行相关 Node 测试、DevEco 构建及 `focusanchor-repo-maintainer` 的安全扫描；设备和平台结果单独标注。
4. PR 指向受审查的集成分支，列明需求、文件范围、共享契约影响、真实测试命令与结果、未验证项。手机 UI V3.1 在负责人查看效果前不得并入其他路线。
5. 不提交 `7_Key/`、`9_Dataset/`、证书、口令、原始个人数据、本地恢复包或未经审核的媒体。不得把 Mock、Replay、模拟器结果写成真机或真实 AgentArts 调用。

分支可以作为备份和审查入口上传私有仓库；测试未通过的分支必须在 PR 中标为 WIP。共享契约、授权、Task/Action 状态源和平台发布按总体章程门禁处理。历史分支保留，不用 force push 覆盖。
