# 属性与旋钮定制的 iCloud 同步和文件重命名设计

本文档详述了 PhantomKnob macOS 应用程序的设置持久化及云同步设计，包括将自定义规则文件从 `rules.json` 重命名为 `my_knobs.json`，以及引入 `NSUbiquitousKeyValueStore` (iCloud KVS) 来保证在应用重装或多设备间设置不丢失。

## User Review Required

> [!IMPORTANT]
> 1. **iCloud Entitlement 要求**：为了启用 iCloud Key-Value Store 同步，必须在 App 的 `PhantomKnob.entitlements` 中启用 `com.apple.developer.ubiquity-kvstore-identifier`。在本地非付费证书开发环境下，如果因为签名无法同步，系统会自动回退到本地存储而不发生崩溃。
> 2. **硬件检测结果本地独占**：触控板检测结果 `com.phantomknob.detectionResult` 因强依赖于当前设备的物理硬件，**不应**参与 iCloud 同步。

---

## Open Questions

目前该方案不需要任何额外的配置，无未决问题。

---

## Proposed Changes

### Storage Component

#### [MODIFY] [RuleLibrary.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Storage/RuleLibrary.swift)
- 将本地持久化路径中的文件名从 `rules.json` 变更为 `my_knobs.json`。
- 新增通知机制（或利用现有的 `ControlRuleDidUpdate`）以便同步服务捕获自定义旋钮规则的变化。

#### [MODIFY] [PhantomKnob.entitlements](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnob.entitlements)
- 添加 `com.apple.developer.ubiquity-kvstore-identifier` 键，启用 iCloud 键值对同步支持。

---

### Service Component

#### [NEW] [CloudSyncManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/CloudSyncManager.swift)
- 引入单例 `CloudSyncManager.shared`，负责协调本地与云端的数据流。
- **启动初始化**：
  - 注册 `NSUbiquitousKeyValueStore.didChangeExternallyNotification` 监听器，响应来自云端的数据变更。
  - 注册本地通知监听器（`ControlRuleDidUpdate`、`com.phantomknob.hotkeyDidChange`、以及对 `skipUserGuideOnStartup` 变化的检测）。
  - 执行首次本地向云端的同步（如果云端为空，本地有数据，则将本地数据推送至云端）。
- **本地变更同步到云端**：
  - 当接收到 `ControlRuleDidUpdate`（用户保存旋钮）时，读取 `my_knobs.json` 的字节流，将其保存到 iCloud KVS 的键 `com.phantomknob.my_knobs.data` 中，并调用 `.synchronize()`。
  - 当快捷键变更时，将更新后的键值写入 KVS 并同步。
  - 当跳过引导设置变更时，同步写入 KVS。
- **云端同步到本地**：
  - 当收到 `didChangeExternallyNotification` 时，检查更改的 Key。
  - 若 `com.phantomknob.my_knobs.data` 发生改变，获取对应二进制数据并安全写入本地 `my_knobs.json`，接着调用 `RuleLibrary.shared.reload()` 刷新内存与界面。
  - 若快捷键相关的 Key 发生改变，更新本地 `UserDefaults`，并触发相应的通知刷新界面。

#### [MODIFY] [PhantomKnobApp.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/App/PhantomKnobApp.swift)
- 在 `AppState.init()` 中实例化并启动 `CloudSyncManager.shared`，以确保在应用生命周期的最早期建立同步监听。

---

### Test Component

#### [NEW] [CloudSyncManagerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift)
- 编写单元测试验证 `CloudSyncManager` 在本地规则更新时正确输出 KVS 的行为，并模拟云端推送通知时本地的重载逻辑。

---

## Verification Plan

### Automated Tests
- 运行针对 `RuleLibraryTests` 和新编写的 `CloudSyncManagerTests` 的单元测试：
  ```bash
  xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'
  ```

### Manual Verification
1. **文件名变更测试**：启动应用并添加一个自定义旋钮，验证 `~/Library/Application Support/PhantomKnob/` 目录下成功生成了 `my_knobs.json`，且不再创建老的 `rules.json`。
2. **iCloud KVS 同步测试**（若当前设备已登录 iCloud 且有沙盒权限）：
   - 修改全局快捷键为 `⌘⌥K`，并在本地添加一个针对 QuickTime 的自定义规则。
   - 检查 `NSUbiquitousKeyValueStore` 是否已包含更新的键值对。
   - 在另一台登录了同一 Apple ID 的测试设备上运行（或模拟云端发出 `didChangeExternallyNotification` 通知），验证本地快捷键自动变更为 `⌘⌥K` 且旋钮自定义列表中出现了新增的规则。
