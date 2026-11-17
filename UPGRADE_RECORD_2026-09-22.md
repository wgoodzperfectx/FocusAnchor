# DevEco Studio / HarmonyOS SDK Upgrade Record

## Scope

- Project: `Huang-A/pig-master`
- Upgrade target: DevEco Studio 26.0.0 and HarmonyOS SDK 26.0.0
- Backup: `D:\70_Competition\FocusAnchor_backup_20260922`

## Pre-upgrade configuration

- `targetSdkVersion`: `6.1.1(24)`
- `compatibleSdkVersion`: `6.1.1(24)`
- `modelVersion`: `6.1.1`
- Hypium: `@ohos/hypium@1.0.25`
- Hamock: `@ohos/hamock@1.0.0`
- Signing store: `D:/70_Competition/FocusAnchor/7_Key/Keystore.p12`
- Signing profile: `D:/70_Competition/FocusAnchor/7_Key/Focusanchor_app_profileDebug.p7b`
- Signing certificate: `D:/70_Competition/FocusAnchor/7_Key/FocuaAnchor.cer`
- Emulator/SDK environment variables: none were exposed in the current PowerShell session
- DevEco Studio process check: no `devecostudio` process was running during this change

## Repository-side change

`build-profile.json5` now uses `26.0.0` for both `targetSdkVersion` and `compatibleSdkVersion`.

## Remaining IDE checks

1. Install DevEco Studio 26.0.0 in a separate directory and install/select HarmonyOS SDK 26.0.0.
2. Verify Ohpm and SDK paths in IDE settings.
3. Recheck signing material under Project Structure; reselect files if paths are invalid.
4. Sync, run `ohpm install`, build HAP/APP, and run on an emulator/device.
5. Confirm `New > Extension Ability` exposes the `Agent` scenario.
