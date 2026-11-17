# FocusAnchor consolidation policy

- `codex/workflow-v21`:主体 App / Workflow。保留 G0、Task/Action 状态源、Agent 桥接和跨端边界。混合改动按逻辑拆分。
- `codex/ux-v3-1`: 手机 UI/UX。项目负责人查看前不合并其他路线。
- `codex/watch-ux-v3-2`: 历史手表路线；`v3-3`: 候选基线；`v3-4`: EXPERIMENTAL 人机交互路线。不要按版本号替代。
- `codex/modeling-task0`: 研究代码与报告。WESAD→NURSE 外部泛化 FAIL，不接生产主动触达。
- `Modeling-Portability-Check`: detached 检查树，未提交成果需单独保存。
- `8_Drive/pig-master`: 独立同步副本，本轮只读检查独有提交与内容，不合并、删除、移动或覆盖。

所有工作树以实时 Git 登记为准。共享契约尚未批准；遇到语义冲突生成变更提案并隔离受影响模块。不得把 Mock、Replay 或历史测试当作本轮真机/平台证据。未提交内容优先留在原目录；stash 不可作为唯一备份。禁止 `git worktree remove --force`。
