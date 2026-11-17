# Task 1 — 数据注册与清单阶段结果

> 2026-11-14 状态更新：NURSE 的 `Stress_dataset.zip` 与 `SurveyResults.xlsx` 已在 `9_Dataset`，前者 SHA-256 与 Dryad 官方元数据匹配；`reports/data_inventory.json` 已重新生成。下文 2026-10-31 的 `BLOCKED_DOWNLOAD` 保留为当时的历史记录。当前 Task 4 结果见 `reports/m1_cross_dataset.md`，K-EmoPhone 仍 `BLOCKED_ACCESS`。

日期：2026-10-31（首次清单 2026-10-29，2026-10-31 复核）；分支：`codex/modeling-task0`。本阶段修改范围：`datasets/registry.yaml`、`scripts/data_inventory.py`、`reports/data_inventory.json`、本报告。没有修改 HarmonyOS、Agent、权限或签名文件。

## 已完成与证据

- 建立四个优先数据集的来源、许可/访问、规模、模态、校验字段和阻塞记录：`datasets/registry.yaml`。
- 建立只读取文件元数据及 ZIP 内容的清单入口：`python scripts/data_inventory.py --dataset-root <LOCAL_PROJECT_ROOT>/9_Dataset --output reports/data_inventory.json --verify-crc`。
- WESAD 本地 `WESAD.zip`：2,249,444,501 字节，SHA256 `5e15d2606adf16d819ba535c1786d92e94bae5ff5392f7ae01fb63f9938fd71c`；ZIP 包 15 个主体、92 个条目，CRC 全部通过。官方页面说明科研非商业、注明来源可用。仅解压目录是部分状态。ZIP 自身的官方哈希未找到，因此仍需保留来源校验限制。
- 2026-10-31 复核发现用户数据目录新增 `mpud.zip`，310,938,979 字节，SHA256 `a8ec974a2c227c30611aea82c59cba85931b8fd73953a90547c9d724f5261179`。用户随后确认此包来自作者分享的 Google Drive，且已接受使用协议。2026-11-01 校验 348 个 ZIP 条目的 CRC 全部通过，确认 342 份用户事件 CSV。协议正文尚未本地归档，因此目前只用于本地研究，不分发原始数据；已核查包内说明及 ESM/传感器字段，以推进 Task 5。
- Dryad 官方 API 文件元数据指出 NURSE `Stress_dataset.zip` 为 1,156,939,542 字节，SHA256 `86e7146cbb124f9b5e37bc5bd8fa63f8786379dfdb10dfc9fdc5fd6c41e63407`；本地未找到该文件。官方下载端点本环境返回 HTTP 401，未尝试非官方来源。

## 数据集阻塞与后续检查

| 数据集 | 状态 | 官方证据 | 阻塞 | 人工/Codex 后续 |
|---|---|---|---|---|
| WESAD | `ARCHIVE_VERIFIED`；预处理待执行 | [Siegen 官方页面](https://ubi29.informatik.uni-siegen.de/usi/data_wesad.html) | 解压目录不完整；标签和信号质量未检查；无官方哈希对照 | Codex 从已校验 ZIP 读取 15 主体并检查标签、腕部模态及质量。 |
| NURSE | `BLOCKED_DOWNLOAD` | [Dryad 数据页](https://datadryad.org/dataset/doi:10.5061/dryad.5hqbzkh6f)、[Dryad CC0 说明](https://datadryad.org/help/guides/reuse) | 官方文件下载 API HTTP 401；数据未在本地 | 人工/Codex 在授权会话复核官方下载；成功后核对 SHA256，取得问卷文件并建立标签映射。 |
| Mobile Phone Use | `USER_ATTESTED_ACCESS_LOCAL_RESEARCH` | [作者数据页](https://sites.google.com/view/mobile-phone-use-dataset)；用户确认 Google Drive 来源及接受协议 | 协议正文尚未归档，不能据此推定分发或部署权利 | Codex 可进行本地离线训练与聚合报告；未来分发或部署前需保留并核对协议正文。 |
| K-EmoPhone | `BLOCKED_ACCESS` | [Zenodo 官方记录](https://zenodo.org/records/7606611) | 需 Zenodo 请求和独立用户协议；本地无数据 | 人工申请并确认获批后才交由 Codex 处理。 |

NURSE 和 K-EmoPhone 仍停止深挖数据本体；Mobile Phone Use 已根据用户的使用协议确认恢复本地研究。NURSE 外部验证仍阻塞，K-EmoPhone contextual head 仍阻塞。

## 命令、结果与验收

执行：`git status --short --branch`、`Get-ChildItem 9_Dataset`、Dryad 官方 API 元数据请求、官方下载端点 HEAD/Range 请求、`python scripts/data_inventory.py ... --verify-crc`。清单脚本输出与 `reports/data_inventory.json` 为本阶段主要机器可读证据。

编译：`NOT_RUN`；自动化测试：`NOT_RUN`（清单/CRC 属数据校验，不计模型测试）；模拟器/真机：`NOT_RUN`；M1/M2 指标：`NOT_RUN`。

**Task 1 总体验收：PARTIAL**（NURSE 下载和 K-EmoPhone 授权仍阻塞；Mobile Phone Use 本地研究已获用户确认）。**WESAD 数据清单子项：PASS**（本地 ZIP 完整性和主体清单）。原始受试者数据保留在 `9_Dataset`，不提交到 Git。
