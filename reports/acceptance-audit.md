# FocusAnchor 建模任务逐项验收核对

日期：2026-11-03，NURSE 项于 2026-11-14 更新；分支：`codex/modeling-task0`。本表只核对当前隔离 worktree 和用户本地数据目录，不把设计文档、并行 UI/UX HAP 或模拟器在线状态当作运行证据。`PASS` 只适用于列明的范围。

| 要求 | 当前证据 | 判定及边界 |
|---|---|---|
| Task 0 仓库、环境、接口、安全边界审计 | `docs/integration-map.md`、`docs/modeling-boundaries.md`、`docs/task0-file-inventory.md`；首个审计提交 `f1f7891` | **PASS**；生产共享契约尚无批准版本。 |
| Task 1 官方来源、许可/访问、规模、模态、哈希及数据清单 | `datasets/registry.yaml`、`reports/data_inventory.json`、`reports/task1-data-status.md`；本地 WESAD/MPUD/NURSE 文件 | **PASS（已提供数据）/ BLOCKED_ACCESS（K-EmoPhone）**；NURSE 官方哈希匹配。WESAD 无官方哈希对照，MPUD 协议正文未归档。真实下载时间未知。 |
| Task 2 30/60/120 秒窗口、主体/时间/标签来源、质量与缺失 | `scripts/preprocess_wesad.py`、`scripts/evaluate_nurse_external.py`、`scripts/assemble_nurse_windows.py`、`data/processed/{wesad,nurse}/manifest.json`；1,824 个 WESAD 窗口，NURSE 30/60/120 秒 9,248/4,544/2,189 窗口 | **PASS（已验证问卷事件子集）**；NURSE 未标记的连续时段没有真值，不当作负类。基础质量规则不等于经真机验证的运动伪影检测。 |
| Task 3 RF/XGBoost、严格 LOSO、每折预测与六项指标、校准和逐主体 | `experiments/m1_wesad_baseline.yaml`、`reports/m1_wesad_metrics.json`、本地忽略的 `predictions/m1/*.parquet`、`calibration/m1/*.json`；`scripts/audit_artifacts.py` 独立核验 6 组、90 折主体互斥 | **PASS（WESAD 内部测试）**；1D-CNN **NOT_RUN**，属于资源允许时的后续比较；不能外推至真实专注状态。 |
| Task 4 WESAD→NURSE zero-shot 外部验证 | `scripts/evaluate_nurse_external.py`、`reports/m1_nurse_external_{30,60,120}s.json`、`reports/m1_cross_dataset.md`；15 人、三个预设窗口 | **PASS（离线外部测试已执行）/ FAIL（模型泛化）**；RF 30/60/120 秒原始概率 AUROC 0.545/0.546/0.528、ECE 0.529/0.491/0.476，不能用于主动触达。全天候真值及生产验证仍缺失。 |
| Task 5 Mobile Phone Use receptivity/timing、用户级 holdout、校准及误打扰代理 | `scripts/preprocess_mpud.py`、`scripts/train_m2_mpud.py`、`reports/m2_receptivity_metrics.json`、`reports/m2_receptivity.md`；`scripts/audit_artifacts.py` 核对 205/68/69 用户拆分及测试预测 | **PASS（本地问卷通知点击代理基线）**；真实介入收益、need score 与真实误打扰未测。K-EmoPhone **BLOCKED_ACCESS**。 |
| Task 6 四端点、OpenAPI、错误码、坏信号降级与回放 | `service/app.py`、`service/openapi.json`、`service/error-codes.md`、`service/replay_fixtures.json`、`tests/test_replay_service.py`；本地 HTTP 与自动化测试 | **PASS（实验回放）**；仅 `0.1-replay`，模型不调用 Agent；网络 TLS、真机与生产接口 **NOT_RUN/BLOCKED_CONTRACT**。 |
| Task 7 HarmonyOS G0、网络 client、调试页和单元测试 | `entry/src/main/ets/modeling/DecisionEngine.ts`、`ReplayClient.ets`、`pages/ModelingReplayDebug.ets`；Node 6/6、Python 9/9、无签名 HAP 此前编译 PASS | **PASS（隔离源码、测试和此前编译）**；2026-11-14 `hdc list targets` 为 `[Empty]`，本建模 HAP 未安装到模拟器，真机未运行；共享许可状态源和生产集成 **BLOCKED_CONTRACT**。 |
| Task 8 环境、种子、哈希、配置、预测、指标、单命令复现和报告 | `experiment_manifest.yaml`、`requirements-modeling.lock.txt`、`scripts/reproduce_core.py`、`scripts/audit_artifacts.py`、`reports/four-week-technical-report.md`；2026-11-14 本机完整单命令重跑退出码 0，覆盖 WESAD/NURSE/MPUD 与回放，独立审计 PASS | **PASS（本机复现材料，含 NURSE）**；完整入口在另一台机器 **NOT_RUN**。预测和模型因数据使用边界保留本地，不提交原始记录。 |

## 当前必须保留的缺口

1. **NURSE 泛化问题**：文件与外部测试已经到位，但 WESAD→NURSE 的 AUROC 仅 0.546，校准误差高，且只有经既有检测系统筛选的事件标签。不能据此发布实时压力估计或调整主动介入阈值。
2. **共享契约及设备闭环**：`docs/changes/CHANGE-MODEL-001.md` 仍为 PROPOSED；章程所述 `architecture-contract.md` 尚未批准。用户正在另一 worktree 调整 UI/UX，不能覆盖其同 bundleName 的 HAP。端侧模型回放、许可状态源、用户确认和现有 Agent 的完整闭环均未验证。
3. **研究证据边界**：MPUD 只有 ESM 点击代理；WESAD 只有实验条件 stress 标签。缺少实际 ADHD 专注改善、真实打扰率与长期使用效果证据。`G0` 阈值仍属实验参数。

验收结论：**局部研究与隔离回放原型 PASS；Task 4 离线外部测试已执行但泛化 FAIL；完整产品闭环仍 BLOCKED_CONTRACT/NOT_RUN（共享契约及设备集成）**。不得以外部测试执行通过代替模型可靠性或真机验证。
