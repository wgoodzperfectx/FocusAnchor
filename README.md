# FocusAnchor 建模研究公开快照

此分支用于审查 M1 情境估计、M2 介入策略及可移植性实验，**不是生产主动干预能力**。WESAD → NURSE 泛化尚未通过；G0 硬性门控仍是执行侧约束。详见 `docs/modeling-boundaries.md` 与 `reports/`。

该快照从本地研究分支整理而来，保留研究文件和实验结果，但不包含原始数据集、模型权重、本地 `.npmrc` 或个人目录路径。文档与清单中的 `<LOCAL_PROJECT_ROOT>` 由研究者按本机目录替换；`9_Dataset` 数据不随 GitHub 分发。原研究分支与完整历史仍保留在本地。

本轮 `node --test tests/*.test.mjs` 为 6/6 通过。Python 测试尚未运行：当前 Python 环境缺少 `pytest`。实验指标不等于真实场景、设备或临床验证。

协作请以 GitHub `main` 为 PR 基线，保留实验性标记；可生产集成候选见 `codex/integration-20261116`。
