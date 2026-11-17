# Task 3 — WESAD M1 主体级基线

日期：2026-10-31；实验配置：`experiments/m1_wesad_baseline.yaml`；输入：`data/processed/wesad/windows.parquet`，SHA256 由 Task 2 manifest 校验。脚本：`scripts/train_m1_wesad.py`。随机种子 1337。环境：Python 3.14.2，NumPy 2.4.4，pandas 3.0.3，scikit-learn 1.8.0，XGBoost 3.4.1，PyArrow 26.0.0。

## 设计与防泄漏

- 外层 15 折 leave-one-subject-out。每折再从其余 14 名主体中固定种子选 3 名做校准，剩余 11 名训练；测试主体、校准主体与训练主体均不重叠。
- RF 与 XGBoost 分别对 30/60/120 秒窗口训练；使用 29 个腕部统计/质量数值特征。`subject_id`、相对时间、`label_purity` 和标签不进入模型特征。
- 同一测试主体的原始、Platt、isotonic 概率并列保存。Platt/isotonic 只在校准主体上拟合；未用外层测试标签调参。`0.5` 分类阈值与 `±0.1` 拒判边界只作离线实验参数，不是医学或部署阈值。
- 每折模型保存在本地 `models/m1/<model>/<window>s/<subject>.joblib`；每折预测合并到 `predictions/m1/<model>_<window>s.parquet`；校准参数在 `calibration/m1/`；机器可读完整指标、逐主体结果、特征重要性和混淆矩阵在 `reports/m1_wesad_metrics.json`。模型与预测文件因原始数据使用约束未提交到 Git，可按命令重建。

## 实测内部结果

下表是各主体留一预测的汇总；RF/XGBoost 的模型在各折不同。显示原始概率，校准方法的全部指标在 JSON 中。

| 模型/窗口 | N | Macro-F1 | Balanced Accuracy | AUROC | AUPRC | ECE | Brier |
|---|---:|---:|---:|---:|---:|---:|---:|
| RF 30s | 1064 | 0.7673 | 0.7720 | 0.8607 | 0.6708 | 0.0567 | 0.1333 |
| XGBoost 30s | 1064 | 0.7610 | 0.7596 | 0.8424 | 0.6582 | 0.1196 | 0.1607 |
| RF 60s | 519 | 0.8513 | 0.8533 | 0.9023 | 0.8494 | 0.0689 | 0.1056 |
| XGBoost 60s | 519 | 0.8285 | 0.8303 | 0.9003 | 0.8482 | 0.0717 | 0.1072 |
| RF 120s | 241 | 0.8558 | 0.8544 | 0.9253 | 0.8860 | 0.0847 | 0.0965 |
| XGBoost 120s | 241 | 0.8385 | 0.8426 | 0.9288 | 0.8735 | 0.0863 | 0.1048 |

60 秒 RF 的逐主体 Macro-F1 最小 0.4098（S14）、中位 0.8504、最大 1.0000；说明汇总分数掩盖明显个体差异。60 秒 RF 原始概率在实验拒判带外的覆盖率为 0.8998。逐主体混淆矩阵、AUROC、AUPRC、ECE、Brier、校准斜率/截距、覆盖率和特征重要性见 JSON。

校准效果不一致：60 秒 RF 原始 Brier 0.1056，Platt 0.1230、isotonic 0.1224；60 秒 XGBoost 的 Platt ECE 从 0.0717 降至 0.0504，但 Brier 从 0.1072 升至 0.1129。不能仅凭单一 ECE 决定上线概率或门控阈值。120 秒性能较高，但窗口更长且样本更少；目前不把它视为已验证的产品最优窗口。

## 命令与核验

```powershell
.\.venv\Scripts\python.exe scripts/train_m1_wesad.py --config experiments/m1_wesad_baseline.yaml --output-root .
```

试跑先执行 RF 60 秒 15 折；完整命令完成 6 个模型/窗口实验、90 个折，写出 90 个模型文件。随后实际读回全部六个预测 Parquet，核对输入哈希、每折主体不交叉、每主体测试一次、预测行数/唯一键、预测及校准文件 SHA256，结果为 `M1 ARTIFACT AUDIT PASS`。本阶段不做部署或设备测试。

编译：`NOT_RUN`；自动化测试：上述数据/分割/产物断言 `PASS`，HarmonyOS 测试 `NOT_RUN`；模拟器/真机：`NOT_RUN`。

## 阻塞与结论

NURSE 官方下载 401，故 WESAD→NURSE 外部验证 `BLOCKED_DOWNLOAD`；Mobile Phone Use 的协议文本尚待归档，M2 指标 `NOT_RUN`；K-EmoPhone `BLOCKED_ACCESS`。当前只证明 WESAD 研究数据内的主体级判别，不证明真实场景压力识别、情绪/专注识别、干预效益或设备可用性。

Task 3 内部 RF/XGBoost 基线：**PASS**。1D-CNN：**NOT_RUN**，需在资源评估后决定是否执行；Task 4 外部验证仍受 NURSE 阻塞。
