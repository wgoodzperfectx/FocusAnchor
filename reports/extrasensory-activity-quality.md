# ExtraSensory 活动情境预处理与质量检查

日期：2026-11-12。输入为 UCSD 公开的逐用户特征/标签包，本地 `9_Dataset/ExtraSensory.per_uuid_features_labels.zip`；来源用途见 `reports/added-data-status.md`。仅保留 72 个手机/手表加速度特征、时间戳、用户 ID 和 `OR_exercise`、`FIX_walking`、`FIX_running` 三个标签。输出为本地 Git 忽略的 `data/processed/extrasensory/activity.parquet`，机器可读质量数据及源/输出哈希见 `data/processed/extrasensory/manifest.json`。

执行命令：

```powershell
.\.venv\Scripts\python.exe scripts/preprocess_extrasensory.py --archive '<LOCAL_PROJECT_ROOT>\9_Dataset\ExtraSensory.per_uuid_features_labels.zip'
```

结果：60 个逐用户 `csv.gz` 全部读取，377,346 行；`(user_id,timestamp)` 无重复，三种标签的已知值均为 0/1。`OR_exercise` 已知 240,837 行，其中正例 8,081、负例 232,756；未知 136,509 行。仅 44 名用户有已知 `OR_exercise` 标签，44 名有正例。72 个加速度特征的单列缺失率中位数约 35.1%；288 行所有加速度特征均缺失。`FIX_running` 未知 236,476 行。缺失不能当作负例；若后续训练需按用户隔离、处理类别不平衡和缺失，并单独评估 OOD/拒判。

本阶段不训练情境模型，不输出真实 `activity=exercise`，不修改 G0 或手机/手表。ExtraSensory 活动标签只可支持独立情境研究，不是 WESAD stress、NURSE 外部验证、MPUD receptivity 或 FocusAnchor 介入收益的标签。

验收：数据完整性/预处理/基础质量 **PASS**；活动模型指标 **NOT_RUN**；编译 **NOT_RUN**；自动化测试 **NOT_RUN**（执行了文件/键/标签断言及 ZIP CRC）；模拟器/真机 **NOT_RUN**。下一步若训练，应先固定用户级划分和实验目标，再报告逐用户结果与校准。
