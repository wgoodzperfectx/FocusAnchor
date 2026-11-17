# GitHub 公开发布检查（2026-11-17）

## 远端与分支

目标仓库：[wgoodzperfectx/FocusAnchor](https://github.com/wgoodzperfectx/FocusAnchor)，项目负责人明确选择 **Public**；API 复核 `private=false`。本地 `github` Remote 指向该仓库，Gitee `origin` 保留。默认分支 `main` 是独立的初始 README 提交；集成分支已合入其历史，GitHub Compare 可用，草稿 [PR #1](https://github.com/wgoodzperfectx/FocusAnchor/pull/1) 尚未合并。

| 已上传分支 | 远端 HEAD | 定位 |
|---|---|---|
| `codex/integration-20261116` | `a13f90d` | 集成候选；PR #1 草稿 |
| `codex/ux-v3-1` | `7a06b40` | 手机 UX WIP；负责人审阅前不合并 |
| `codex/workflow-v21` | `8bd265b` | 工作流 WIP；真实平台联调待验证 |
| `codex/watch-ux-v3-2` | `5cf6ebd` | 历史基线 |
| `codex/watch-ux-v3-3` | `4a2fbd4` | 集成所用手表候选 |
| `codex/watch-ux-v3-4` | `db3da0a` | 未完成的人机交互实验 |
| `codex/modeling-public-20261117` | `61fbc38` | 脱敏研究快照；非生产主动干预 |

`codex/modeling-task0` 与 `codex/archive-modeling-portability-20261116` 的原始历史含本机数据路径，仅本地保留；公开快照包含经脱敏的实验文件与结果。`8_Drive` 独立副本、`7_Key`、`9_Dataset` 均未上传。Phone UX 与 Workflow 的本地 `build-profile.json5` 含签名口令，未提交；Workflow 原始日志与截图仍留本地。

## 本轮安全与许可检查

- 对集成树 127 个已跟踪文件运行 `publication_scan.py`：敏感扩展名、常见秘密模式、超过 10 MB 文件和常见原始数据/模型扩展名均为 0。42 个媒体文件的公开权利与画面隐私由项目负责人明确确认。
- 对 7 个已上传分支的 HEAD 文件树做定向复扫：`.p12/.p7b/.cer/.csr/.env/.hap/.zip/.7z` 路径均为 0；口令、私钥头和常见令牌模式只命中集成分支的扫描脚本自身。46 个先前本地可达提交的敏感扩展名路径扫描为 0。该检查不等于全面秘密或版权审计。
- Modeling 公开快照去除本地 `.npmrc` 和已识别的绝对本机路径，不包含原始数据集或权重；其 JSON 文件可解析。
- 根 `LICENSE` 为 GPL-2.0。项目负责人确认本次图片和录屏可公开；后续新增第三方资产仍须单独审查。

## 本轮验证

| 范围 | 结果 |
|---|---|
| Integration Node | 19/19 PASS |
| Watch V3.3 透明素材 | 9 项 PASS |
| Integration `entry` / `wear` DevEco 26 `assembleHap` | 普通构建 PASS；Hvigor 明确跳过签名 |
| Workflow 原树 Node | 204/204 PASS；AgentArts 合成 Replay 子集 26/26、UX 子集 35/35 |
| Phone UX 原树 Node | 57/59；两项因缺少 `WorkflowV21Mocks.ts` 无法加载，故 WIP |
| Modeling 公开快照 Node | 6/6 PASS；Python 测试未运行（本机缺少 `pytest`） |
| Knowledge Governance 规则示例 | `asset-kb-check.py --self-test` 4/4 PASS；非生产过滤器 |
| 真实 AgentArts、签名身份、模拟器/真机、真实双端 ACK | NOT_RUN |

测试和构建结果仅证明列出的范围；没有将 Mock、Replay 或未签名构建当作平台或设备验收。
