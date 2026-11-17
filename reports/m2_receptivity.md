# Task 5 — Mobile Phone Use 问卷点击可接受度基线

日期：2026-11-01；分支：`codex/modeling-task0`。状态：**PASS（离线 receptivity 代理基线）/ BLOCKED（K-EmoPhone contextual head）**。本阶段没有接入 Agent、Workflow、HarmonyOS、生理采集或生产门控。

## 数据和标签

- 源包：`<LOCAL_PROJECT_ROOT>/9_Dataset/mpud.zip`，310,938,979 字节，SHA256 `a8ec974a2c227c30611aea82c59cba85931b8fd73953a90547c9d724f5261179`；348 个 ZIP 条目，CRC 全部通过。用户确认来自作者分享的 Google Drive，已接受使用协议。协议正文未本地归档，因此仅用于本地研究，不分发原始记录或模型作为产品。
- 原包 `Sensors.xlsx` 将 `EsmAll` 描述为“完成或忽略问卷”，包含 Posted、Clicked、Timedout。训练标签是**体验采样问卷通知在发出后 10 分钟内是否被点击**；有超时且无点击为负例。没有完整结局的记录排除。此标签不等于用户希望接受 FocusAnchor 帮助、帮助有效或许可主动触达。
- 流式扫描 342 名用户的 31,562,291 条事件，发现 114,085 条 ESM 记录。排除 801 条时间/结局含糊记录、15 个同键结局冲突通知，移除 656 条同标签重复行，最终 112,598 条通知（正例 32,518，28.9%）。无无效时间、时间逆序、空特征值或重复通知键。
- 特征只有通知时点前的时间、屏幕、应用、通知、通话、活动、电量和环境噪声摘要；不使用通知后的点击、超时、回答内容、问卷情绪或个人档案。状态值可能来自较早的最近一次观测；尚未评价传感器陈旧性对模型的影响。

## 切分与模型

固定随机种子 1337，按用户分为训练 205 人/67,265 行、校准 68 人/22,722 行、测试 69 人/22,611 行；三组用户无交集。LR 与 XGBoost 在训练用户上拟合；Platt 只在校准用户上拟合，测试用户未参与选择特征或阈值。按校准集 Brier 选择概率版本：LR raw 0.1659 对 Platt 0.1678，XGB raw 0.1569 对 Platt 0.1575，因此两者选 raw；测试集未参与该选择。模型和逐事件预测存于本地忽略目录，聚合指标及哈希见 `reports/m2_receptivity_metrics.json`。

| 模型/概率 | Macro-F1 | Balanced Acc. | AUROC | AUPRC | ECE(10) | Brier | 误打扰代理率* |
|---|---:|---:|---:|---:|---:|---:|---:|
| LR raw | 0.6046 | 0.6015 | 0.7607 | 0.5488 | 0.0481 | 0.1769 | 0.3792 |
| LR Platt | 0.5994 | 0.5978 | 0.7607 | 0.5488 | 0.0528 | 0.1807 | 0.3749 |
| XGB raw | 0.6432 | 0.6329 | 0.7865 | 0.5930 | 0.0233 | 0.1666 | 0.3478 |
| XGB Platt | 0.6472 | 0.6363 | 0.7865 | 0.5930 | 0.0505 | 0.1694 | 0.3519 |

\* 阈值 0.5 下预测“可点击”而实际未点击的通知，占全部预测“可点击”通知的比例，即 `FP/(TP+FP)`。这是问卷通知的**离线误打扰代理**，不是 FocusAnchor 真实误打扰率。XGB raw 有 3,657 次预测正例，其中 1,272 次假阳性。测试用户每人 44–814 条通知；该代理率在测试用户中的中位数为 0.3333，最高 0.8235，显示个体差异大。Platt 未同时改善本次 ECE/Brier，不能宣称校准有效。

## 复现与边界

```powershell
.\.venv\Scripts\python.exe scripts/preprocess_mpud.py --archive <LOCAL_PROJECT_ROOT>/9_Dataset/mpud.zip
.\.venv\Scripts\python.exe scripts/train_m2_mpud.py
```

输入表：`data/processed/mpud/receptivity.parquet`（本地忽略）；清单：`data/processed/mpud/manifest.json`；实验配置：`experiments/m2_mpud_receptivity.yaml`；模型：`models/m2_receptivity_lr.joblib`、`models/m2_receptivity_xgb.joblib`（本地忽略）；测试预测：`predictions/m2/*.parquet`（本地忽略）。上述预测涉及用户事件，不能提交到仓库。另一台机器需自行合法取得源包并核对哈希。

K-EmoPhone 仍为 `BLOCKED_ACCESS`，因此 attention/task-disturbance contextual head 未训练；HeartSteps 因果评价未运行。M2 在此阶段只是候选分数，`G0 / Hard Gate` 的授权决策及 `Channel C / AUTHORIZED_CONTEXT_EVENT` 接入尚未实现。共享 `architecture-contract.md` 未冻结，脚本字段不是生产接口。

编译：`NOT_RUN`（纯 Python 离线阶段）；自动化测试：`PASS`，`.\.venv\Scripts\python.exe -m unittest discover -s tests -p test_preprocess_mpud.py -v`，1 项通知前特征边界测试通过；模拟器/真机：`NOT_RUN`。本阶段验收仅限离线 M2 基线及数据质量门槛。
