# Task 6 — FastAPI 实验推理与回放服务

日期：2026-11-01；分支：`codex/modeling-task0`；状态：**PASS（本地实验回放服务）/ BLOCKED（共享生产接口与设备集成）**。

## 文件与接口

- `service/app.py`：`GET /v1/health`、`POST /v1/m1/estimate`、`POST /v1/m2/decision-candidate`、`GET /v1/replay/next`。
- `service/openapi.json`：从实际 FastAPI app 导出的 OpenAPI；`service/error-codes.md`：拒判与错误码。
- `service/replay_fixtures.json`：仅从 WESAD/MPUD 特征中位数构造的合成回放 fixture，没有原始参与者行或身份。
- `scripts/train_m1_replay.py`：全体 15 名 WESAD 主体的 RF 60 秒回放工件，519 窗口、29 特征；哈希见 `reports/m1_replay_artifact.json`。此全量工件未做独立测试和校准；Task 3 的 LOSO 指标不等于此工件的独立验证。
- `models/m2_receptivity_xgb.joblib` 来自 Task 5 主体留出实验。校准集 Brier 选择 raw 概率；仍只代表问卷通知点击代理，不是介入收益或用户许可。

`PhysioSample` 单点无法驱动当前窗口模型；因此服务使用仅供回放的 `PhysioWindow`，版本 `0.1-replay`，仅接受 `source=replay`。M1 的正常回放概率也标记 `physio_state=unknown`、`calibration_status=uncalibrated`。M2 无经验证的 need 模型，缺少用户主动请求时始终 `abstain/NEED_UNOBSERVED`；用户主动请求时可产生 `ask/defer` **候选**，仍 `executable=false`。任何响应都没有通知、Task 写入、Agent 调用或生产授权。

`docs/changes/CHANGE-MODEL-001.md` 已提出共享窗口、候选动作和 Workflow 2.1.0 的兼容映射；状态 `PROPOSED`。未经项目负责人/工作流专题审查，不更新共享 `architecture-contract.md` 或接入 App。

## 执行与证据

```powershell
.\.venv\Scripts\python.exe scripts/train_m1_replay.py
.\.venv\Scripts\python.exe scripts/build_replay_fixtures.py
.\.venv\Scripts\python.exe -m unittest discover -s tests -p test_replay_service.py -v
.\.venv\Scripts\python.exe -m uvicorn service.app:app --host 127.0.0.1 --port 8765
```

6 项服务测试通过，覆盖 OpenAPI/health、M1 未校准拒判、坏信号、缺特征、M2 缺 need、OOD/坏情境、模型不可用和版本错误。实际本地 HTTP 调用返回 `health=replay_only`、`agent_connected=false`；合成 MPUD fixture 返回 `action=abstain`、`NEED_UNOBSERVED`、`executable=false`。另用一条合法本地 MPUD 特征行配合**合成**用户主动请求验证了 `ask` 候选路径，分数 0.8846、`executable=false`；该行和身份未写入仓库。测试客户端出现 Starlette `httpx` 弃用警告，不影响本次结果，但依赖升级时需重测。

编译：`NOT_RUN`（Python 服务由导入、测试和本地 Uvicorn 启动验证）；自动化测试：`PASS`（6 项）；模拟器/真机：`NOT_RUN`。未验证：网络 TLS、端侧兼容、真实数据实时采集、真实 Agent/工作流回调、设备故障处理。NURSE 外部验证仍 `BLOCKED_DOWNLOAD`；K-EmoPhone 仍 `BLOCKED_ACCESS`。下一阶段 Task 7 只能新增隔离的端侧门控原型，不得接管现有提醒或 Agent。
