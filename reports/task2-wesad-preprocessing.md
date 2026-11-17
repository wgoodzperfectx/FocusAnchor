# Task 2 — WESAD 统一窗口与信号质量

> 2026-11-14 更新：NURSE 30/60/120 秒的已验证问卷事件窗口、统一清单与外部验证现见 `data/processed/nurse/manifest.json`、`reports/m1_cross_dataset.md`。下文 `BLOCKED_DOWNLOAD` 是本报告原始阶段的历史状态。未标记的 NURSE 连续时段没有真值，未当作负类。

日期：2026-10-31；分支：`codex/modeling-task0`。本阶段仅新增 `scripts/preprocess_wesad.py`、`.gitignore` 中的生成物排除规则、`data/processed/wesad/manifest.json` 和本报告。`windows.parquet` 在本 worktree 本地生成并被 Git 忽略；原始数据仍在用户的 `9_Dataset`，不会提交受试者信号。

## 输入与方法

- 输入：`<LOCAL_PROJECT_ROOT>/9_Dataset/WESAD.zip`，Task 1 已验证 15 主体 ZIP CRC；SHA256 见 manifest。读取 `WESAD/Sx/Sx.pkl` 时用受限 NumPy unpickler，仅允许已检查到的数组构造类型。
- 标签来自同步 pickle 的 700 Hz `label`，按官方 `wesad_readme.pdf`：1 baseline、2 stress、3 amusement；0/4/5/6/7 排除。二分类只将 2 映射为 stress，1/3 映射为 non-stress。每个窗口要求主标签占比至少 95%；过渡窗口不进入训练表。
- 腕部 BVP 64 Hz、EDA/TEMP 4 Hz、ACC 32 Hz，按同步记录的相对秒数切片。30/60/120 秒分别使用无重叠 stride。`window_start_ms/end_ms` 均为**相对同步记录起点**，不冒充绝对时间戳。
- 保存 `subject_id`、`session_id`、窗口边界、原标签、二分类标签、标签纯度与来源；各通道统计、缺失率、基本物理范围异常率及 `good/degraded/invalid` 质量字段。无插值。质量阈值是工程筛查参数，不是医学阈值；BVP 运动伪影与跨设备校准尚未充分评估。

## 运行命令与结果

```powershell
.\.venv\Scripts\python.exe scripts/preprocess_wesad.py --archive '<LOCAL_PROJECT_ROOT>\9_Dataset\WESAD.zip' --output-dir data/processed/wesad
```

运行结果：15 主体，1,824 行；30 秒 1,064 行、60 秒 519 行、120 秒 241 行。二分类 non-stress 1,279、stress 545。基本质量检查标记 good 1,824、degraded 0、invalid 0；所有输出特征当前无空值。排除的过渡/非目标标签窗口详见 `data/processed/wesad/manifest.json`。运行时 NumPy 对旧 pickle dtype 产生 `VisibleDeprecationWarning`，本次解码成功；将其作为环境兼容风险保留。

结构核验：Parquet 读回行数与 manifest 一致；15 个唯一主体；窗口长度等于边界差；无 `(subject_id, window_seconds, window_start_ms)` 重复；标签纯度均达到 95%；标签来源字段存在。重新运行的计数与输出哈希核验见下方复现结果。

复现结果：同一命令改用 `--output-dir tmp/wesad-repeat` 再次执行，15 主体、三种窗口计数、标签分布、质量分布、逐主体摘要和 Parquet SHA256 均一致。两次 Parquet SHA256 同为 `a471afac98e3d0f7b3667349b2ff1b1dfe0ef9f4068c1fd977e9c18c4f795282`。

## 阻塞、依赖与验收

- NURSE 官方下载阻塞，不在本阶段处理；Mobile Phone Use 许可待人工确认；K-EmoPhone 限制访问。详见 `reports/task1-data-status.md`。
- 本阶段尚无主体级 train/test 划分、模型拟合或校准。Task 3 必须按主体外层留一，校准主体与训练/测试主体分离；Task 4 外部验证需 NURSE。
- 编译：`NOT_RUN`；自动化测试：结构核验已执行，模型测试 `NOT_RUN`；模拟器/真机：`NOT_RUN`；模型指标：`NOT_RUN`。

Task 2 WESAD 子项验收：**PASS**（非重叠窗口、标签来源、基本信号质量与重复运行已核验）。NURSE 预处理：`BLOCKED_DOWNLOAD`。Task 2 全数据集范围：**BLOCKED**。
