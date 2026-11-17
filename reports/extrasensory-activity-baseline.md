# ExtraSensory 活动情境研究基线

日期：2026-11-12。目标是评估公开逐用户加速度特征能否为未来 G0 的运动排除提供研究证据；本实验不提供端侧 `activity` 状态、不触发提示、不接入现有 G0。

输入：本地 `data/processed/extrasensory/activity.parquet`；配置 `experiments/extrasensory_activity.yaml`；脚本 `scripts/train_extrasensory_activity.py`。源 ZIP、处理表和配置的哈希见 `reports/extrasensory_activity_metrics.json`，原始 ZIP SHA256 为 `412d307bdf54a60dff81a705c2f25833889a46dca64a184e3b588ad99c69cb56`。只使用有明确 `OR_exercise` 0/1 标签、且至少一个加速度特征非空的记录。未知标签没有被当成负例。

按用户固定种子 1337 划分：26 人训练（159,253 行）、9 人校准保留（38,998 行）、9 人测试（42,584 行）；三个集合互斥。72 个手机/手表加速度特征，不包括用户 ID、时间戳和其他标签。Logistic Regression 用训练集 median imputation、标准化和类别权重；XGBoost 用训练集类别权重并直接处理 NaN。校准保留集仅报告原始概率指标，本次没有拟合概率校准器；测试集未用于训练或阈值选择。模型及逐行预测保留在本地 Git 忽略目录，JSON 中有逐用户测试指标。

| 测试集原始概率 | Macro-F1 | Balanced Accuracy | AUROC | AUPRC | ECE(10) | Brier | 预测运动中的假阳性 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Logistic Regression | 0.6134 | 0.7078 | 0.7747 | 0.3734 | 0.2093 | 0.1036 | 4,110 / 5,161 |
| XGBoost | 0.6015 | 0.7018 | 0.7894 | 0.3969 | 0.1449 | 0.0903 | 4,559 / 5,608 |

测试正例 2,033 / 42,584，类别不平衡明显。当前固定 0.5 阈值的假阳性太多，校准误差亦高；这些概率不能进入 G0 的确定性排除条件。逐用户结果及原始分数见 JSON，不能把随机生活情境的 exercise 标签解释为 FocusAnchor 干预收益。

执行与核验：

```powershell
.\.venv\Scripts\python.exe scripts/preprocess_extrasensory.py --archive '<LOCAL_PROJECT_ROOT>\9_Dataset\ExtraSensory.per_uuid_features_labels.zip'
.\.venv\Scripts\python.exe scripts/train_extrasensory_activity.py
```

两条命令均退出码 0。独立读回测试预测，按 seed 重建用户划分并核对 26/9/9 互斥、测试用户集合、行数及预测 SHA256，均 PASS。编译 **NOT_RUN**；自动化模型测试 **PASS（上述产物断言）**；模拟器/真机 **NOT_RUN**；真实活动来源、概率校准、OOD、个人化和端侧延迟均 **NOT_RUN**。阶段验收 **PASS（离线研究基线）/ BLOCKED（G0 集成证据）**。
