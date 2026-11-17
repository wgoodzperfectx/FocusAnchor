# AGC 云调试准备情况（2026-10-11）

## 结论

工程可用 DevEco Studio 26.0.0.821 的 SDK 构建并签名，已生成手机、手表 HAP 和包含双模块的 APP 包，具备提交 AGC 云调试的包体条件。运行效果、麦克风输入、通知和跨设备同步仍需在云真机上验证。

## 已核实

| 项目 | 结果 |
| --- | --- |
| ArkTS 与资源构建 | `assembleApp --mode project -p product=default -p buildMode=debug` 成功，75 个任务 |
| 包体签名 | 手机和手表 `*-signed.hap` 均通过 `hap-sign-tool verify-app` |
| 设备类型 | `entry`: phone/tablet；`wear`: wearable |
| 包名 | `com.focusanchor.focuxanchor` |
| 最低兼容版本 | API 26；云设备的系统 API 版本必须不低于 26 |
| 图标资源 | 手机与手表各 8 张 320×240 透明 PNG，均在对应 HAP 中 |
| 引导一步流程 | 8 状态可操作，进度本地保存，打开页面时通过分布式 KV 与另一端同步 |

## 上传包

- 手机单独调试：`entry/build/default/outputs/default/entry-default-signed.hap`
- 手表单独调试：`wear/build/default/outputs/default/wear-default-signed.hap`
- 双模块包：`build/outputs/default/pig-master-default-signed.app`

在 AGC 的“质量 → 云调试”选择**系统 API 版本不低于 26**的对应设备。先用手机 HAP 验证首页、引导一步的 8 状态、语音授权和任务编辑，再用手表 HAP 验证圆屏布局及状态按钮。双端实时同步需要同账号、可分布式协同的手机和手表同时运行；单台云设备无法证明该场景通过。

## 仍需注意

1. 心率目前是模拟数据，云真机看到心率变化不代表传感器已接入。
2. “拆成小步”目前生成可编辑的 5 分钟首步模板，不是 AI 自动分解；用户确认后进入执行流程。
3. 配置中使用本机调试签名材料的绝对路径；在别的电脑重建时须重新配置签名。`build-profile.json5` 已被 Git 跟踪，含本机签名密码字段，发布或共享仓库前应迁移到本机私有配置；若此前已共享，应轮换这些凭据。
4. 构建有既有 ArkTS 警告（异常处理提示及 `showToast` 废弃提示），没有编译错误。

## 复现构建

```powershell
$env:DEVECO_SDK_HOME = 'D:\Tools\DevEco26\DevEco Studio\sdk'
& 'D:\Tools\DevEco26\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleApp --mode project -p product=default -p buildMode=debug --no-daemon
```

图标可从原始设计稿重新提取：

```powershell
python scripts/extract_status_icons.py <phone-sheet.png> <watch-sheet.png>
```
