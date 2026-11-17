# M1 WESAD → NURSE 离线外部验证

日期：2026-11-14；分支：`codex/modeling-task0`。本报告只评价 NURSE **经过受试者确认的问卷事件时段**。没有连续无压力时段的完整真值，也没有手机/手表运行证据。

## 数据、标签和固定协议

- [Dryad 原始记录](https://datadryad.org/dataset/doi:10.5061/dryad.5hqbzkh6f)与[原论文](https://pmc.ncbi.nlm.nih.gov/articles/PMC9159985/)说明 ZIP 含 15 位护士的 E4 会话，问卷 `0/1/2` 分别为无/中/高压力；`na` 是模型建议但未经受试者验证的事件。原论文注明采集地 CST 比 GMT 晚 6 小时。问卷的时区字段缺失，故按该说明固定转换；夏令时或记录误差仍可能影响配对。
- 原始 `Stress_dataset.zip` 1,156,939,542 字节，SHA-256 `86e7146cbb124f9b5e37bc5bd8fa63f8786379dfdb10dfc9fdc5fd6c41e63407`，与 Dryad 官方元数据一致。`SurveyResults.xlsx` 49,048 字节，SHA-256 `4ee7733f8e8da362af33a765c495f4a5ed8302b5af39327c2cdb420a27def2b3`。文件留在 `9_Dataset`，不提交 Git。
- 使用 Task 3 已训练的 WESAD RF 30/60/120 秒各 15 个 LOSO 折模型作**固定等权集成**；RF 120 秒是 WESAD 内部 Macro-F1 最高的组合，30/60 秒是规范预设的窗口对照。各折 Platt/isotonic 仅用 WESAD 校准主体训练。特征、非重叠窗口、二元映射（NURSE 1/2 为正类）、0.5 分类阈值、±0.1 实验拒判区间均在 NURSE 评分前确定。未用 NURSE 训练、校准、选阈值或挑模型。模型哈希、逐主体摘要与预测哈希见 `reports/m1_nurse_external_{30,60,120}s.json`；本地预测见 `data/processed/nurse/{30,60,120}s/external_predictions.parquet`。统一窗口表与清单见 `data/processed/nurse/windows.parquet`、`manifest.json`。
- 问卷中 358 条有 ID：245 条有 `0/1/2` 标签，113 条 `na` 排除。ZIP 有 609 个会话，136 个与已验证问卷事件相交；仅完整处于事件和会话内的窗口进入评估。每个窗口保留主体、会话、UTC 起止毫秒、原始/二元标签、问卷来源、质量与缺失字段。冲突标签窗口 0，质量规则判为 invalid 的窗口 0；这套基础质量规则不能证明运动伪影已被排除。

## 测试结果

30/60/120 秒集分别有 9,248/4,544/2,189 个窗口、均为 15 人，阳性分别 7,843/3,853/1,858，阴性分别 1,405/691/331。AUPRC 的阳性比例基线约 0.85，须与此基线比较。以下分数按窗口汇总；同一事件内窗口相关，不能视为独立事件。

| WESAD 窗口与校准方式 | Macro-F1 | Balanced Accuracy | AUROC | AUPRC | ECE | Brier | ±0.1 拒判率 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 30 秒原始概率 | 0.331 | 0.528 | 0.545 | 0.872 | 0.529 | 0.461 | 14.9% |
| 30 秒 Platt | 0.329 | 0.528 | 0.541 | 0.870 | 0.547 | 0.477 | 12.8% |
| 30 秒 Isotonic | 0.352 | 0.527 | 0.536 | 0.871 | 0.532 | 0.475 | 14.2% |
| 60 秒原始概率 | 0.341 | 0.522 | 0.546 | 0.873 | 0.491 | 0.420 | 20.8% |
| 60 秒 Platt | 0.329 | 0.521 | 0.549 | 0.873 | 0.513 | 0.441 | 17.3% |
| 60 秒 Isotonic | 0.334 | 0.524 | 0.548 | 0.873 | 0.516 | 0.453 | 13.7% |
| 120 秒原始概率 | 0.339 | 0.529 | 0.528 | 0.875 | 0.476 | 0.401 | 20.8% |
| 120 秒 Platt | 0.326 | 0.527 | 0.534 | 0.875 | 0.504 | 0.443 | 13.8% |
| 120 秒 Isotonic | 0.315 | 0.538 | 0.536 | 0.876 | 0.519 | 0.457 | 7.4% |

60 秒原始概率混淆矩阵（TN/FP/FN/TP）为 `532/159/2796/1057`；120 秒为 `262/69/1362/496`。WESAD 内部 RF 60 秒 LOSO 原始概率 AUROC 0.902、ECE 0.069；RF 120 秒 AUROC 0.925。跨到 NURSE 后区分度与校准均显著下降。60 秒拒判后的原始概率覆盖 3,600 窗口，Balanced Accuracy 0.540；120 秒覆盖 1,734 窗口，Balanced Accuracy 0.545。这些值只描述已保留窗口，不是干预安全保证。两组均有 12 人同时拥有两类窗口可计算个人 AUROC，另外 3 人只有阳性窗口；逐人样本与分数见 JSON。

## 判定及限制

**Task 4 外部测试执行 PASS；跨数据集模型泛化 FAIL。** NURSE 的已验证事件来自既有压力检测系统的候选片段，并经护士确认，属于选择后的样本。它不能估计全天候无压力假阳性率。WESAD 实验条件标签与 NURSE 主观事件等级并不等价；总体 AUPRC 还受 84.8% 阳性比例影响。WESAD 内部 Platt/isotonic 校准没有迁移到 NURSE。模型输出不得作为真实用户压力概率、主动提醒阈值或 G0 授权依据。

复现：在本 worktree 的 `.venv` 中运行 `python scripts/evaluate_nurse_external.py --archive <LOCAL_PROJECT_ROOT>/9_Dataset/Stress_dataset.zip --survey <LOCAL_PROJECT_ROOT>/9_Dataset/SurveyResults.xlsx --window 30`，再分别以 `--window 60`、`--window 120` 运行，最后运行 `python scripts/assemble_nurse_windows.py`。编译：`NOT_RUN`（仅 Python 离线实验）；自动化测试：Python 9/9、Node 6/6、`pip check` PASS；模拟器/真机：`NOT_RUN`。共享 `architecture-contract.md` 仍未批准；本阶段无生产集成。
