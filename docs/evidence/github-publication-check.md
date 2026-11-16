# GitHub 发布前检查（2026-11-16）

**状态：BLOCKED。** 当前 `origin` 为 Gitee `master`，未配置 GitHub Remote，也未核验 GitHub 仓库地址、可见性或默认分支。未创建仓库、Push、Release 或更改远端。

| 检查 | 结果 |
|---|---|
| README / Demo | 已新增产品 README、本地 Demo 和能力矩阵；README 检测器可按提交差异提示复核 |
| 本地测试 | 本轮 Node 19/19、素材 9 项、README 检测器 2/2 通过 |
| 构建/设备 | 本轮 DevEco 26 `entry`、`wear` 构建成功但未签名；模拟器与真机 NOT_RUN |
| 凭证/签名 | `publication_scan.py` 对已跟踪文件扫描：敏感文件名 0、常见私钥/API Key 模式命中 0；无法保证无其他形式秘密，仍需人工复核 |
| 大文件 | 已跟踪文件未发现超过 10 MB；录屏 MP4 存在于 `docs/evidence/watch-v3.3/`，需确认发布许可和隐私 |
| 数据/模型 | 扫描未发现已跟踪的常见数据/权重扩展名；项目根 `9_Dataset/` 不应自动纳入公开仓库 |
| 许可 | 根 `LICENSE` 为 GPL-2.0；原有代码与第三方素材、录屏、知识资产权利尚未逐项确认 |
| Git LFS | 当前已跟踪文件未超 10 MB；`git lfs ls-files` 未列出对象，托管配额未核验 |
| 可复现性 | 本地 Node Demo 可运行；完整 App/AgentArts/双端 Demo 尚未建立 |

建议在权利与敏感内容审查通过后，先从 `codex/integration-20261116` 建立受审查的 GitHub 候选分支，再单独决定远端创建与 Push。当前不建议公开发布。

**推荐远端方案（尚未执行）：**项目负责人确认目标 GitHub 仓库地址和可见性后，将本地集成提交复制到 `codex/github-demo-candidate` 审查分支；完成素材许可、个人信息、签名与构建产物复核，再以该候选分支 Push 到新配置的 GitHub Remote。默认分支和 Release 单独决议，不直接推送 Gitee `master`。可公开候选为已审查的源码、README、Demo/测试脚本与脱敏架构资料；排除项目根 `7_Key/`、`9_Dataset/`、本地恢复包、未审核素材及个人信息。仓库内现有 42 个媒体文件需逐项确认权利与画面隐私后再决定公开范围。

**扫描范围限制：**脚本检查 Git 已跟踪文件的路径、大小与少量高风险字符串；不覆盖 Git 历史、未跟踪文件、压缩包内部或第三方版权。扫描快照保存在项目本地 `10_Codex/reports/repository-consolidation/publication-scan.json`。
