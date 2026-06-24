# HoBle

HoBle 是一个 HarmonyOS 6 的 BLE 后台守护应用。它会尽量维持蓝牙广播和长时后台任务，让 Mac 端持续发现设备。

## 现有能力

- 保存广播标识
- 请求蓝牙、位置和后台运行权限
- 启动 / 停止 BLE 广播
- 启动 / 停止长时后台任务
- 显示实时状态和诊断日志
- 记录 HarmonyOS 6 应用查杀事件和上次异常退出原因
- 复制 Mac 端匹配配置（`manufacturerId + deviceId`）

## HarmonyOS 6 诊断增强

当前版本已经接入 `HiAppEvent.APP_KILLED` 订阅和 `LaunchParam.lastExitReason` 启动诊断，用来解释系统资源管控、性能管控、用户清理、后台长时任务暂停/取消等守护中断原因。主页的“系统诊断”卡只展示系统 API 能证明的事实，不把进程重启后的 BLE 广播状态推断成仍在运行。

Live View Kit 需要应用具备实况窗权益，且锁屏实况窗还涉及 `LiveViewLockScreenExtensionAbility`。当前项目先不默认启用 Live View，后续需要确认权益、审核场景和真机行为后再接入。

## 目录

- `entry/src/main/ets/pages/Index.ets`：主页 UI
- `entry/src/main/ets/services/GuardCenter.ets`：状态编排
- `entry/src/main/ets/services/GuardDiagnosticsService.ets`：系统查杀、上次退出和后台事件诊断
- `entry/src/main/ets/services/BleAdvertiser.ets`：BLE 广播
- `entry/src/main/ets/services/BackgroundTaskService.ets`：后台任务
- `entry/src/main/ets/services/PermissionService.ets`：权限申请
- `entry/src/main/ets/services/SettingsStore.ets`：本地配置持久化

## 环境

这个项目依赖 DevEco Studio 自带的工具链，不要直接拿系统 Java 或系统 Node 代替。

- DevEco Studio
- HarmonyOS SDK
- JBR: `/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home`
- SDK: `/Applications/DevEco-Studio.app/Contents/sdk`
- hvigorw: `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`

如果你在别的机器上构建，需要把 `build-profile.json5` 里签名证书、profile 和 `local.properties` 里的 SDK 路径改成你自己的。

## 本地构建

先确认 DevEco 环境变量，然后在仓库根目录执行：

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin:/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH

/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap -p product=default -p buildMode=release --no-daemon
```

调试包把 `buildMode=release` 改成 `buildMode=debug` 即可。

release 产物默认在：

- `entry/build/default/outputs/default/entry-default-signed.hap`

如果 hvigor 报 Java 或缓存相关问题，先停掉 daemon 再重试：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --stop-daemon
```

## GitHub Release

仓库里的 `.github/workflows/release.yml` 会在 `v*` tag 推送时，或者手动触发时：

1. 用 DevEco 工具链重新打 release HAP
2. 把 `entry/build/default/outputs/default/entry-default-signed.hap` 上传到 GitHub Release

这个 workflow 需要 self-hosted runner，并且 runner 上要能访问上面的 DevEco 安装路径和签名配置。
