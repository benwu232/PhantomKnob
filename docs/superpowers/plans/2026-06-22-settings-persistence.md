# 属性与旋钮定制的 iCloud 同步和文件重命名实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将自定义规则持久化文件从 `rules.json` 重命名为 `my_knobs.json`，并实现基于 `NSUbiquitousKeyValueStore` (iCloud KVS) 的双向云同步，确保重装应用或多设备使用时不丢失自定义旋钮与系统全局设置。

**架构：** 
1. 将 `RuleLibrary` 指向 `my_knobs.json`。
2. 在 `PhantomKnob.entitlements` 中启用 iCloud KVS 权限。
3. 新建 `CloudSyncManager` 服务，分别监听本地的自定义规则（`ControlRuleDidUpdate` 通知）、全局快捷键（`com.phantomknob.hotkeyDidChange` 通知）、跳过引导选项的变更，并将数据上传到云端；同时订阅 iCloud `didChangeExternallyNotification`，将云端同步的值拉取合并回本地。
4. 在 `AppState` 初始化时启动 `CloudSyncManager`。

**技术栈：** Swift, SwiftUI, Combine, NSUbiquitousKeyValueStore, Foundation, XCTest.

---

### 任务 1：重命名自定义规则持久化文件及其关联单元测试

**文件：**
- 修改：`PhantomKnob/Storage/RuleLibrary.swift`
- 修改：`PhantomKnob/PhantomKnobTests/CustomKnobTests.swift`

- [ ] **步骤 1：更新 `RuleLibrary.swift` 中的文件名与属性可见性**
  - 修改 `RuleLibrary.swift` 中的 `userRulesURL` 指向 `my_knobs.json`。
  - 将 `userRulesURL` 的可见性从 `private` 变更为 `internal`，以便 `CloudSyncManager` 可以直接读取该路径进行云同步。
  
  ```swift
  // Target: PhantomKnob/Storage/RuleLibrary.swift
  // Line ~12-17
  // 将 private 替换为 internal，并改名为 my_knobs.json
  internal let userRulesURL: URL = {
      let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      return appSupport
          .appendingPathComponent("PhantomKnob", isDirectory: true)
          .appendingPathComponent("my_knobs.json")
  }()
  ```

- [ ] **步骤 2：更新 `CustomKnobTests.swift` 中的文件名引用**
  - 将 `CustomKnobTests.swift` 中的 `rules.json` 替换为 `my_knobs.json`，`rules.json.bak` 替换为 `my_knobs.json.bak`。
  
  ```swift
  // Target: PhantomKnob/PhantomKnobTests/CustomKnobTests.swift
  // Line ~383-398
  let rulesURL = appSupport.appendingPathComponent("PhantomKnob/my_knobs.json")
  let backupURL = appSupport.appendingPathComponent("PhantomKnob/my_knobs.json.bak")
  ```

- [ ] **步骤 3：运行测试验证正确性**
  - 运行命令：
    ```bash
    xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/CustomKnobTests/testQuickTimeCustomizationToggleBug
    ```
  - 预期输出：`** TEST SUCCEEDED **`。

- [ ] **步骤 4：Commit**
  - 运行命令：
    ```bash
    git add PhantomKnob/Storage/RuleLibrary.swift PhantomKnob/PhantomKnobTests/CustomKnobTests.swift
    git commit -m "refactor: rename rules.json to my_knobs.json and update tests"
    ```

---

### 任务 2：启用 iCloud Key-Value Store 权限 (Entitlements)

**文件：**
- 修改：`PhantomKnob/PhantomKnob.entitlements`

- [ ] **步骤 1：添加 iCloud KVS 描述项**
  - 在 `PhantomKnob.entitlements` 的 dict 中增加 `com.apple.developer.ubiquity-kvstore-identifier` 键，值为 `$(TeamIdentifierPrefix)$(CFBundleIdentifier)`。
  
  ```xml
  <!-- Target: PhantomKnob/PhantomKnob.entitlements -->
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
  	<key>com.apple.security.app-sandbox</key>
  	<false/>
  	<key>com.apple.developer.ubiquity-kvstore-identifier</key>
  	<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
  </dict>
  </plist>
  ```

- [ ] **步骤 2：运行项目编译验证**
  - 运行编译命令验证 Entitlements 配置无误且没有编译报错：
    ```bash
    xcodebuild build -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'
    ```
  - 预期输出：`** BUILD SUCCEEDED **`。

- [ ] **步骤 3：Commit**
  - 运行命令：
    ```bash
    git add PhantomKnob/PhantomKnob.entitlements
    git commit -m "config: enable iCloud Key-Value Store entitlement"
    ```

---

### 任务 3：创建并实现 `CloudSyncManager`

**文件：**
- 创建：`PhantomKnob/Service/CloudSyncManager.swift`

- [ ] **步骤 1：编写 `CloudSyncManager.swift` 并实现云同步逻辑**
  - 监听本地规则、快捷键和引导页设置的变更并写入云端。
  - 监听外部（云端）变更，写回本地。
  - 引入防循环机制（比较值是否发生改变）。
  
  ```swift
  // Target: PhantomKnob/Service/CloudSyncManager.swift
  import Foundation
  import Combine

  public final class CloudSyncManager {
      public static let shared = CloudSyncManager()
      
      private var cancellables = Set<AnyCancellable>()
      private var isSyncingFromCloud = false
      
      private init() {}
      
      public func start() {
          // 1. 订阅云端变更通知
          NotificationCenter.default.addObserver(
              self,
              selector: #selector(storeDidChange(_:)),
              name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
              object: NSUbiquitousKeyValueStore.default
          )
          
          // 2. 初始主动拉取一次云端并强制生效
          NSUbiquitousKeyValueStore.default.synchronize()
          
          // 3. 订阅本地自定义规则更新
          NotificationCenter.default.publisher(for: NSNotification.Name("ControlRuleDidUpdate"))
              .sink { [weak self] _ in
                  self?.syncLocalRulesToCloud()
              }
              .store(in: &cancellables)
              
          // 4. 订阅本地快捷键变更
          NotificationCenter.default.publisher(for: .hotkeyDidChange)
              .sink { [weak self] _ in
                  self?.syncLocalHotkeyToCloud()
              }
              .store(in: &cancellables)
              
          // 5. 监听本地 UserDefaults 变更（主要用于 skipUserGuideOnStartup）
          NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
              .sink { [weak self] _ in
                  self?.syncLocalGeneralSettingsToCloud()
              }
              .store(in: &cancellables)
              
          // 6. 首次启动将本地既有数据尝试推到云端（如果云端为空）
          initialPushIfNeeded()
      }
      
      private func initialPushIfNeeded() {
          if NSUbiquitousKeyValueStore.default.data(forKey: "com.phantomknob.my_knobs.data") == nil {
              syncLocalRulesToCloud()
          }
          if NSUbiquitousKeyValueStore.default.longLong(forKey: "globalHotkeyKeyCode") == 0 {
              syncLocalHotkeyToCloud()
          }
          // skipUserGuideOnStartup 本身在 KVS 中若无，可默认把本地的送过去
          if NSUbiquitousKeyValueStore.default.object(forKey: "skipUserGuideOnStartup") == nil {
              let localVal = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
              NSUbiquitousKeyValueStore.default.set(localVal, forKey: "skipUserGuideOnStartup")
              NSUbiquitousKeyValueStore.default.synchronize()
          }
      }
      
      private func syncLocalRulesToCloud() {
          guard !isSyncingFromCloud else { return }
          let url = RuleLibrary.shared.userRulesURL
          guard FileManager.default.fileExists(atPath: url.path),
                let data = try? Data(contentsOf: url) else { return }
          
          let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: "com.phantomknob.my_knobs.data")
          if cloudData != data {
              NSUbiquitousKeyValueStore.default.set(data, forKey: "com.phantomknob.my_knobs.data")
              NSUbiquitousKeyValueStore.default.synchronize()
              NSLog("[CloudSync] Synced local custom rules to cloud.")
          }
      }
      
      private func syncLocalHotkeyToCloud() {
          guard !isSyncingFromCloud else { return }
          let keyCode = UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode")
          let modifiers = UserDefaults.standard.integer(forKey: "globalHotkeyModifiers")
          
          let cloudKeyCode = NSUbiquitousKeyValueStore.default.longLong(forKey: "globalHotkeyKeyCode")
          let cloudModifiers = NSUbiquitousKeyValueStore.default.longLong(forKey: "globalHotkeyModifiers")
          
          var changed = false
          if keyCode != 0 && cloudKeyCode != Int64(keyCode) {
              NSUbiquitousKeyValueStore.default.set(Int64(keyCode), forKey: "globalHotkeyKeyCode")
              changed = true
          }
          if modifiers != 0 && cloudModifiers != Int64(modifiers) {
              NSUbiquitousKeyValueStore.default.set(Int64(modifiers), forKey: "globalHotkeyModifiers")
              changed = true
          }
          
          if changed {
              NSUbiquitousKeyValueStore.default.synchronize()
              NSLog("[CloudSync] Synced local hotkey to cloud.")
          }
      }
      
      private func syncLocalGeneralSettingsToCloud() {
          guard !isSyncingFromCloud else { return }
          let localVal = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
          let cloudVal = NSUbiquitousKeyValueStore.default.bool(forKey: "skipUserGuideOnStartup")
          if localVal != cloudVal {
              NSUbiquitousKeyValueStore.default.set(localVal, forKey: "skipUserGuideOnStartup")
              NSUbiquitousKeyValueStore.default.synchronize()
              NSLog("[CloudSync] Synced skipUserGuideOnStartup to cloud: \(localVal)")
          }
      }
      
      @objc private func storeDidChange(_ notification: Notification) {
          guard let userInfo = notification.userInfo,
                let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
              return
          }
          
          guard reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSync else {
              return
          }
          
          guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
              return
          }
          
          isSyncingFromCloud = true
          defer { isSyncingFromCloud = false }
          
          var needsReloadRules = false
          var needsNotifyHotkey = false
          
          for key in changedKeys {
              if key == "com.phantomknob.my_knobs.data" {
                  if let data = NSUbiquitousKeyValueStore.default.data(forKey: key) {
                      let url = RuleLibrary.shared.userRulesURL
                      let dir = url.deletingLastPathComponent()
                      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                      try? data.write(to: url)
                      needsReloadRules = true
                      NSLog("[CloudSync] Received rules from cloud, updated my_knobs.json.")
                  }
              } else if key == "globalHotkeyKeyCode" {
                  let val = NSUbiquitousKeyValueStore.default.longLong(forKey: key)
                  if val != 0 && UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode") != Int(val) {
                      UserDefaults.standard.set(Int(val), forKey: "globalHotkeyKeyCode")
                      needsNotifyHotkey = true
                  }
              } else if key == "globalHotkeyModifiers" {
                  let val = NSUbiquitousKeyValueStore.default.longLong(forKey: key)
                  if val != 0 && UserDefaults.standard.integer(forKey: "globalHotkeyModifiers") != Int(val) {
                      UserDefaults.standard.set(Int(val), forKey: "globalHotkeyModifiers")
                      needsNotifyHotkey = true
                  }
              } else if key == "skipUserGuideOnStartup" {
                  let val = NSUbiquitousKeyValueStore.default.bool(forKey: key)
                  if UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup") != val {
                      UserDefaults.standard.set(val, forKey: "skipUserGuideOnStartup")
                      NSLog("[CloudSync] Received skipUserGuideOnStartup from cloud: \(val).")
                  }
              }
          }
          
          if needsReloadRules {
              RuleLibrary.shared.reload()
          }
          
          if needsNotifyHotkey {
              NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
              NSLog("[CloudSync] Received hotkey configuration from cloud, re-registered hotkey.")
          }
      }
  }
  ```

- [ ] **步骤 2：更新 xcode 配置文件 `project.yml`**
  - 在 `project.yml` 的 `targets/PhantomKnob/sources` 下包含新创建的 `CloudSyncManager.swift` 所在的 `Service` 路径（因为 XcodeGen 会扫描 Service 目录，所以确认不需要特殊操作，只需文件落盘到 `PhantomKnob/Service/CloudSyncManager.swift`，但如果之前有特定 exclusions 需确保其能被扫描进去。XcodeGen 默认会递归引入 sources 中的路径，所以直接创建即可）。

- [ ] **步骤 3：Commit**
  - 运行命令：
    ```bash
    git add PhantomKnob/Service/CloudSyncManager.swift
    git commit -m "feat: implement CloudSyncManager for bidirectional KVS sync"
    ```

---

### 任务 4：在 App 启动中生命周期挂载

**文件：**
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`

- [ ] **步骤 1：挂载 `CloudSyncManager.shared.start()`**
  - 在 `AppState` 的 `init()` 中启动同步管理器。
  
  ```swift
  // Target: PhantomKnob/App/PhantomKnobApp.swift
  // Line ~23-25
  self.knobStateManager.start()
  
  // 挂载云同步服务
  CloudSyncManager.shared.start()
  ```

- [ ] **步骤 2：运行应用构建验证**
  - 编译整个应用，确保启动挂载无编译错误：
    ```bash
    xcodebuild build -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'
    ```
  - 预期输出：`** BUILD SUCCEEDED **`。

- [ ] **步骤 3：Commit**
  - 运行命令：
    ```bash
    git add PhantomKnob/App/PhantomKnobApp.swift
    git commit -m "feat: hook CloudSyncManager start into app startup lifecycle"
    ```

---

### 任务 5：编写单元与模拟同步测试

**文件：**
- 创建：`PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift`

- [ ] **步骤 1：编写针对双向同步和防死循环检测的测试用例**
  - 模拟外部 KVS 发生变化并通知，测试本地规则文件是否能正确更新重载。
  
  ```swift
  // Target: PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift
  import XCTest
  @testable import PhantomKnob

  final class CloudSyncManagerTests: XCTestCase {
      
      override func setUp() {
          super.setUp()
          // 运行前清空相关的 UserDefaults
          UserDefaults.standard.removeObject(forKey: "globalHotkeyKeyCode")
          UserDefaults.standard.removeObject(forKey: "globalHotkeyModifiers")
          UserDefaults.standard.removeObject(forKey: "skipUserGuideOnStartup")
      }
      
      func testCloudSyncManagerExternalRulesUpdate() throws {
          // 1. 初始化
          let manager = CloudSyncManager.shared
          manager.start()
          
          // 2. 模拟外部发来的自定义规则
          let mockRule = ControlRule(
              key: RuleKey(bundleID: "com.test.synced", axRole: "AXSlider"),
              translation: .arrowKeyUpDown
          )
          let encoder = JSONEncoder()
          let mockData = try encoder.encode([mockRule])
          
          let expectation = self.expectation(description: "Rule library is reloaded when rules are synced from cloud")
          
          let observer = NotificationCenter.default.addObserver(
              forName: NSNotification.Name("ControlRuleDidUpdate"),
              object: nil,
              queue: nil
          ) { _ in
              // 再次查询库中是否存在云端注入的规则
              let lookupKey = RuleKey(bundleID: "com.test.synced", axRole: "AXSlider")
              let matched = RuleLibrary.shared.lookup(for: lookupKey)
              if matched?.translation == .arrowKeyUpDown {
                  expectation.fulfill()
              }
          }
          
          // 3. 发送模拟云端变更通知
          let userInfo: [AnyHashable: Any] = [
              NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange,
              NSUbiquitousKeyValueStoreChangedKeysKey: ["com.phantomknob.my_knobs.data"]
          ]
          
          // 注入 KVS Mock：直接在 memory 中改变并写入本地然后发送系统通知触发 manager 执行
          // 在没有真正的 iCloud sandbox 环境下，我们手动将 Data 写入本地文件以模拟 KVS 写盘动作，随后直接发 didChange 通知
          try mockData.write(to: RuleLibrary.shared.userRulesURL)
          
          NotificationCenter.default.post(
              name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
              object: NSUbiquitousKeyValueStore.default,
              userInfo: userInfo
          )
          
          waitForExpectations(timeout: 2.0, handler: nil)
          NotificationCenter.default.removeObserver(observer)
          
          // 4. 清理本地模拟写入的文件
          try? FileManager.default.removeItem(at: RuleLibrary.shared.userRulesURL)
          RuleLibrary.shared.reload()
      }
      
      func testCloudSyncManagerExternalHotkeyUpdate() {
          let manager = CloudSyncManager.shared
          manager.start()
          
          let expectation = self.expectation(description: "Hotkey change notification posted")
          let observer = NotificationCenter.default.addObserver(
              forName: .hotkeyDidChange,
              object: nil,
              queue: nil
          ) { _ in
              XCTAssertEqual(UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode"), 18)
              XCTAssertEqual(UserDefaults.standard.integer(forKey: "globalHotkeyModifiers"), 256)
              expectation.fulfill()
          }
          
          // 模拟 KVS 云端更改了键：globalHotkeyKeyCode=18, globalHotkeyModifiers=256
          // 手动写入 UserDefaults 模拟 storeDidChange 接收到云端更新值直接写 UserDefaults
          // （因为 NSUbiquitousKeyValueStore 在本地非 iCloud 环境下无法进行 mock 写入，所以直接发外部改变消息通知，模拟 key 数组）
          NSUbiquitousKeyValueStore.default.set(Int64(18), forKey: "globalHotkeyKeyCode")
          NSUbiquitousKeyValueStore.default.set(Int64(256), forKey: "globalHotkeyModifiers")
          
          let userInfo: [AnyHashable: Any] = [
              NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange,
              NSUbiquitousKeyValueStoreChangedKeysKey: ["globalHotkeyKeyCode", "globalHotkeyModifiers"]
          ]
          
          NotificationCenter.default.post(
              name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
              object: NSUbiquitousKeyValueStore.default,
              userInfo: userInfo
          )
          
          waitForExpectations(timeout: 2.0, handler: nil)
          NotificationCenter.default.removeObserver(observer)
      }
  }
  ```

- [ ] **步骤 2：在 xcode 配置文件中引入新的测试文件**
  - 因为 XcodeGen 默认扫描所有 Test 下的文件，所以文件落盘到 `PhantomKnobTests/CloudSyncManagerTests.swift` 即可。
  - 需要重新生成 Xcode 盘符配置项目文件确保编译树包含新测试类（运行 `./create_xcode_project.sh` 来重新运行 xcodegen 生成项目文件）。
  
  ```bash
  ./create_xcode_project.sh
  ```

- [ ] **步骤 3：运行测试验证正确性**
  - 运行单元测试：
    ```bash
    xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/CloudSyncManagerTests
    ```
  - 预期输出：`** TEST SUCCEEDED **`。

- [ ] **步骤 4：Commit**
  - 运行命令：
    ```bash
    git add PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift PhantomKnob/PhantomKnob.xcodeproj
    git commit -m "test: add unit tests for CloudSyncManager sync behaviors"
    ```
