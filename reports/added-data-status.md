# 2026-11-12 新增数据包核验与使用边界

范围：`<LOCAL_PROJECT_ROOT>/9_Dataset` 新增的四个 ZIP。命令：

```powershell
.\.venv\Scripts\python.exe scripts/inventory_added_archives.py --dataset-root '<LOCAL_PROJECT_ROOT>\9_Dataset'
```

输出 `reports/added_data_inventory.json`：四包外层 ZIP CRC 均通过，未发现加密条目或不安全成员路径。SHA256、压缩与声明展开字节数、条目数在机器可读清单及 `datasets/registry.yaml`。只检查 ZIP 元数据/CRC，没有提取或训练原始参与者数据；CLAS 内层包没有检查。

| 包 | 已核实 | 当前判定 |
|---|---|---|
| `swell.zip` | 外层 60 条目，含 `hrv dataset/data/final/{train,test}.csv`、RRI、标签。与 [Kaggle qiriro SWELL HRV](https://www.kaggle.com/datasets/qiriro/swell-heart-rate-variability-hrv) 的衍生 HRV 数据描述相符；页面列 CC0。 | **NEEDS_PROVENANCE_REVIEW**：用户无法恢复下载页面记录，不能认作原始完整 SWELL-KW；暂不接入 M1 对照。 |
| `CLAS.zip` | 外层 CRC PASS，仅含 `CLAS_DATASET.zip`。 | **BLOCKED_ACCESS**：[作者页面](https://snlab.site123.me/clas)要求签署 EULA 并获取密码；用户未能确认本地副本的授权来源，停止内层检查。 |
| `StudentLife.zip` | 外层 1,984 条目，含 `dataset/EMA/...`。 | **NEEDS_SOURCE_REVIEW**：可对应 [Dartmouth StudentLife 项目](https://studentlife.cs.dartmouth.edu/)，但下载来源和数据条款未核实；R 包 GPL 许可不能视为数据许可。 |
| `ExtraSensory.per_uuid_features_labels.zip` | 外层 60 份用户 `csv.gz`，与 [UCSD 官方数据页](https://extrasensory.ucsd.edu/)的公开特征/标签包结构对应。 | **LOCAL_PUBLIC_RESEARCH**：官方允许免费使用并要求引用原论文；可研究情境/活动标签，但没有直接的 FocusAnchor need 或干预收益标签。 |

另外，用户确认 K-EmoPhone 申请未获批准，保持 **BLOCKED_ACCESS**。[GLOBEM 官方页](https://physionet.org/content/globem/1.1/)标注 credentialed access，本地没有文件，保持 **BLOCKED_ACCESS**。NURSE 仍未在目录中，WESAD→NURSE 外部验证 **BLOCKED_DOWNLOAD**。这些数据不能相互冒充外部验证。

本阶段仅扩展注册与清单：编译 **NOT_RUN**；自动化测试 **NOT_RUN**（ZIP CRC/哈希属于数据完整性核验）；模拟器/真机 **NOT_RUN**；新数据模型指标 **NOT_RUN**。接下来可在许可和任务标签明确时选择 ExtraSensory 的独立情境实验；不把它并入已有 WESAD stress 或 MPUD 点击代理指标。
