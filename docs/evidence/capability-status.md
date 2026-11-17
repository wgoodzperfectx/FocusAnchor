# 能力状态矩阵（2026-11-17）

IMPLEMENTED 指本分支代码和本地验证；MOCK / REPLAY 指合成输入；EXPERIMENTAL 指研究；BLOCKED 指前置缺口；NOT_RUN 指本轮未执行。状态仅覆盖下列证据。

| 能力 | 状态 | 证据与边界 |
|---|---|---|
| Watch V3.3 候选界面/队列 | IMPLEMENTED | `wear/src/main/ets/`；`tests/wear-ux-v3-2.test.mjs` 10/10；设备未测 |
| AgentArts 后端解析/调用边界 | MOCK / REPLAY | `scripts/agentarts-runtime-client.mjs`、`AgentArtsSse.ts`；合成测试 9/9 |
| AgentArts 真实 Provider→App | BLOCKED | 无真实调用、鉴权、响应映射和 App 注入证据 |
| Knowledge Base V2 | BLOCKED | 未集成 Schema/检索评估；旧资产在 `Wang-B-Agent/knowledge-base/` |
| 手机—手表真实 ACK | NOT_RUN | 本地队列测试不能证明双设备送达 |
| 主体 FormKit 回写 | NOT_RUN | 未执行卡片回写测试 |
| 独立元服务 | NOT_RUN | `Zeng-C/FocusAnchorMetaService-final/` 未集成/实测 |
| M1/M2 | EXPERIMENTAL | Modeling 独立工作树；WESAD→NURSE 泛化 FAIL，不能生产触达 |
| 手机 UI V3.1 | BLOCKED | 独立 WIP 分支已上传，含签名配置的本地修改未提交；负责人审阅前不合并；本轮全量测试 57/59 |
| Watch V3.4 人机交互 | EXPERIMENTAL | 未完成实验；不替代 V3.3 |
| `entry` / `wear` SDK 构建 | IMPLEMENTED | 本轮 DevEco 26 Hvigor `assembleHap` 均成功；`SignHap` 明确跳过签名；签名身份及安装 NOT_RUN |
| 模拟器/真机 | NOT_RUN | 本集成分支未运行 |
