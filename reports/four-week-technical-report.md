# FocusAnchor 建模四周阶段技术报告

> **2026-11-14 复现补充**：`python scripts/reproduce_core.py --dataset-root <LOCAL_PROJECT_ROOT>/9_Dataset` 已在本机完整重跑并以退出码 0 结束，现覆盖 WESAD 6 组/90 折、NURSE 30/60/120 秒外测、MPUD 342 用户 M2、隔离回放材料及 `scripts/audit_artifacts.py`。NURSE 窗口数 9,248/4,544/2,189，原始概率 AUROC 0.545/0.546/0.528，与前次报告相同。模型和预测文件的字节哈希随本机重跑改变，报告已更新到当前产物；指标在报告精度内一致。跨机器重跑仍 `NOT_RUN`。

> **2026-11-14 补充**：NURSE 数据已下载并核对官方 ZIP SHA-256；Task 2 的 30/60/120 秒问卷事件窗口分别为 9,248/4,544/2,189 条。WESAD→NURSE 固定 RF 三窗口的原始概率 AUROC 0.545/0.546/0.528、ECE 0.529/0.491/0.476，Platt/isotonic 未改善校准。Task 4 离线测试已执行，但泛化 FAIL；旧文中的 `BLOCKED_DOWNLOAD` 是 2026-11-03 的历史状态。详见 `reports/m1_cross_dataset.md` 和 `reports/m1_nurse_external_{30,60,120}s.json`。共享契约、设备与生产闭环仍未验证。

日期：2026-11-03；分支：`codex/modeling-task0`。本报告按框架的四周目标归档实际完成范围，不表示经过四周真实用户试验或生产部署。

## Week 1：数据、边界与契约

Task 0 仓库和接口审计已提交，证据为 `docs/integration-map.md`、`docs/modeling-boundaries.md`、`docs/task0-file-inventory.md`。Task 1 注册和清单见 `datasets/registry.yaml`、`reports/data_inventory.json`。Task 2 从已核验 WESAD ZIP 产生 15 主体的 30/60/120 秒腕部窗口，共 1,824 行，见 `data/processed/wesad/manifest.json`。共享 `architecture-contract.md` 尚未批准，`docs/changes/CHANGE-MODEL-001.md` 仍为 PROPOSED。NURSE 官方下载受阻；K-EmoPhone 未获访问许可。

## Week 2：M1 内部基线

`experiments/m1_wesad_baseline.yaml` 固定 seed 1337、RF/XGBoost、三个窗口和 15 主体留一外层测试。每折校准主体从非测试主体分离。共 6 个模型/窗口组合、90 个主体折。完整逐折结果、原始/Platt/isotonic 校准与预测文件路径在 `reports/m1_wesad_metrics.json`；预测与模型留在本地忽略目录。RF 60 秒原始概率：Macro-F1 0.8513、Balanced Accuracy 0.8533、AUROC 0.9023、AUPRC 0.8494、ECE 0.0689、Brier 0.1056。该数值只代表 WESAD 内部测试，不能证明跨数据集或 ADHD 干预效果。1D-CNN 未执行。

## Week 3：外部验证与 M2

WESAD→NURSE zero-shot 外部测试为 `BLOCKED_DOWNLOAD`，不存在外部测试分数；标签映射和特征可比性待数据到位后核定，见 `reports/m1_cross_dataset.md`。Mobile Phone Use 的用户来源/接受协议由用户确认，协议正文未归档，因此仅本地研究。342 位用户事件经历史特征构造，112,598 条通知问卷点击代理标签。M2 XGBoost 严格按用户拆分（205/68/69 train/cal/test），测试集 22,611 条：AUROC 0.7865、AUPRC 0.5930、Macro-F1 0.6432、ECE 0.0233、Brier 0.1666。所谓误打扰率 0.3478 只是未点击代理上的假阳性占预测正例比例，并非真实用户打扰测量。见 `reports/m2_receptivity_metrics.json` 和 `reports/m2_receptivity.md`。K-EmoPhone 未执行。

## Week 4：隔离回放与端侧安全门控

Task 6 的 FastAPI 只使用合成聚合夹具回放；M1 全主体回放模型未单独验证/校准，服务仍输出 `physio_state=unknown`。M2 不具备独立的 need score，Channel C 情境事件默认 abstain。服务候选均不可执行。Task 7 的 HarmonyOS `G0 / Hard Gate` 代码处理许可、DND、冷却期、未知活动、坏信号、OOD/不确定、近期拒绝和过期候选；任何结果保持 `executed=false`。隔离调试页仅消费回放夹具，未接入 Agent 或现有 UI。见 `reports/task6-replay-service.md`、`reports/task7-decision-engine.md`。

## 复现与当前验收

合法取得两份数据并安装 `requirements-modeling.lock.txt` 的 Python 3.14.2 环境中，在仓库根目录执行：

```powershell
python scripts/reproduce_core.py --dataset-root '<authorized-dataset-root>'
```

入口先核验两份原始 ZIP SHA256，再重建两个预处理表、六组 M1 LOSO 指标和逐折预测、M2 指标和预测、回放模型与合成夹具。配置、版本、seed、源代码基准提交和预期产物见 `experiment_manifest.yaml`。原始数据和逐行预测不纳入 Git；其他机器须自行合法取得档案。2026-11-03 在本机 `.venv` 用上列单命令完整重跑，退出码 0，打印 `CORE REPRODUCTION PASS`。WESAD 1,824 行、6 组/90 折；Mobile Phone Use 112,598 行，342 用户，M2 205/68/69 用户拆分。M1 的 RF 60 秒和 M2 XGBoost 指标与前次报告在所列四位小数精度一致；个别浮点尾数、预测文件字节哈希和生成时间戳发生变化，因此此验收证明指标与流程复现，不声称跨机器逐字节相同。每次运行的产物哈希由入口对当前指标文件核验。

产物独立审计：`python scripts/audit_artifacts.py` PASS，确认 M1 六组/90 折训练、校准、测试主体互斥，逐折预测行数对应窗口；M2 按 seed 重建的 205/68/69 用户拆分互斥且两个测试预测文件均仅含测试用户。该审计已接入后续的单命令复现入口；本次变更未重新完整执行耗时数据预处理。

自动化验证：`node --test tests/decision_engine.test.mjs` 为 6/6 PASS；`python -m unittest discover -s tests -v` 为 8/8 PASS；`python -m pip check` PASS。Task 7 无签名 HAP 的 `hvigorw assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon` 编译 PASS（2026-11-03 时间戳修正后再构建通过，详见 `reports/task7-decision-engine.md`）。用户已启动手机和手表模拟器，但本建模 HAP 未安装到它们，模拟器运行验证 `NOT_RUN`；真机 `NOT_RUN`。

阶段状态：Task 0 PASS；Task 1/2 可访问数据子项 PASS、全范围因 NURSE/K-EmoPhone BLOCKED；Task 3 WESAD 内部 PASS、1D-CNN NOT_RUN；Task 4 BLOCKED_DOWNLOAD；Task 5 Mobile Phone Use 本地基线 PASS、K-EmoPhone BLOCKED_ACCESS；Task 6 隔离回放 PASS、生产集成 BLOCKED_CONTRACT；Task 7 单元测试与无签名构建 PASS、模拟器安装/运行 NOT_RUN、生产集成 BLOCKED_CONTRACT；Task 8 本地单命令复现 PASS、跨机器复现 NOT_RUN。整体原型的研究/回放部分有实证，公开数据到真实用户效果的验证和跨端工作流闭环未完成。

待人工处理：通过官方渠道取得 NURSE 并复核 SHA256 与调查标签；获批后取得 K-EmoPhone；保存 Mobile Phone Use 协议正文以审查分发/部署用途；由负责人批准共享契约和生产集成计划。当前不得把 UI/UX 已安装 HAP 当作建模 HAP 的设备验证。
