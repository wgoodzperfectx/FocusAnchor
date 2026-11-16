# 本地可复现 Demo

在集成分支根目录运行 `node --test tests/*.test.mjs` 和 `python tests/test_wear_v33_assets.py`。当前预期分别为 19 项 Node 测试及 9 个透明素材检查。测试只用合成事件和注入的 `fetch`；不请求 AgentArts，也不证明设备交付。后端适配器为 `scripts/agentarts-runtime-client.mjs`，尚未接入 App。

本轮 Windows/DevEco 26 构建命令（在仓库根目录的 PowerShell 中）：

```powershell
$env:DEVECO_SDK_HOME = 'D:\Tools\DevEco26\DevEco Studio\sdk'
& 'D:\Tools\DevEco26\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry@default assembleHap
& 'D:\Tools\DevEco26\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=wear@default assembleHap
```

先在被 `.gitignore` 排除的 `local.properties` 中配置本机 `hwsdk.dir` 与 `nodejs.dir`。本轮两模块构建成功，但未配置签名；模拟器、真机与双端 ACK 尚未验证。其他机器应改用自身 DevEco/SDK 路径。

构建成功只证明当前 SDK 完成编译与打包；安装运行还需要相应设备、签名与权限条件。首次构建若报 `DEVECO_SDK_HOME` 无效，应核对 SDK 路径并重启 Hvigor daemon 后再执行。
