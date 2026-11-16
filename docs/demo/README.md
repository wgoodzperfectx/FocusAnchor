# 本地可复现 Demo

在集成分支根目录运行 `node --test tests/*.test.mjs` 和 `python tests/test_wear_v33_assets.py`。当前预期分别为 19 项 Node 测试及 9 个透明素材检查。测试只用合成事件和注入的 `fetch`；不请求 AgentArts，也不证明设备交付。后端适配器为 `scripts/agentarts-runtime-client.mjs`，尚未接入 App。HarmonyOS 构建需 DevEco Studio 与匹配 SDK；本分支本轮未完成构建验证。
