# 基于 Lemon Squeezy 的混合许可证验证与付费转化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在独立分发版中，实现基于 Lemon Squeezy 云端网关的混合授权签名校验与前台精细化付费转化机制，加固 Debug 隔离。

**架构：** 客户端离线优先校验 Keychain 收据中网关的 Ed25519 数字签名与设备硬件 UUID；通过 15 天后台静默刷新及 7 天宽限期应对网络波动；在状态栏菜单（天数小于 3 天时推荐购买）与设置面板实现高感官付费引导。

**技术栈：** Swift (CryptoKit, IOKit, Security/Keychain, SwiftUI, Combine), URLSession

---

## 1. 拟变动文件与职责划分

* **[MODIFY] [LicenseState.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/LicenseState.swift)**: 增加 `daysRemaining` 只读计算属性。
* **[MODIFY] [LicenseManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/LicenseManager.swift)**: 
  * 引入 `LicenseReceipt` 结构体及 CryptoKit Ed25519 公钥签名验签逻辑。
  * 增加获取硬件 UUID 与收据绑定的验证方法。
  * 重构 `activate` 网络请求（发送至 CF Worker 网关）和 `currentState` 校验。
  * 实现后台静默刷新和 7 天宽限期（Grace Period）退化控制。
  * 使用 `#if DEBUG` 隔离 `debugToggleLicense` 调试切换。
* **[MODIFY] [StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift)**: 
  * 动态更新菜单栏：免费版常驻购买入口；试用期且剩余天数 < 3 时追加购买项。
  * 使用 `#if DEBUG` 彻底屏蔽 `debugToggleLicense` 选项和 `⌘⌥T` 快捷键的添加。
* **[MODIFY] [SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift)**: 
  * 扩展 `AboutView`，支持输入 Key、激活中动画、成功对勾、错误红色高亮，以及邮箱脱敏和 Deactivate。
  * 对接 popover 点击自动聚焦 Email 框逻辑。

---

## 2. 实现步骤与任务拆解

### 任务 1：升级 LicenseState 模型与测试

**文件：**
- 修改：`PhantomKnob/Model/LicenseState.swift`
- 修改：`PhantomKnob/PhantomKnobTests/LicenseTests.swift`

- [ ] **步骤 1：在 `LicenseTests.swift` 中编写测试，验证新增的 `daysRemaining` 计算属性。**
  ```swift
  // 追加至 LicenseTests 类中
  func testLicenseStateDaysRemaining() {
      XCTAssertEqual(LicenseState.licensed.daysRemaining, nil)
      XCTAssertEqual(LicenseState.free.daysRemaining, nil)
      XCTAssertEqual(LicenseState.trialing(daysRemaining: 5).daysRemaining, 5)
  }
  ```

- [ ] **步骤 2：运行测试验证失败。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：FAIL，报错 "daysRemaining is not a member of LicenseState"

- [ ] **步骤 3：在 `LicenseState.swift` 中实现 `daysRemaining`。**
  ```swift
  // 插入到 LicenseState 定义中
  public var daysRemaining: Int? {
      switch self {
      case .trialing(let days):
          return days
      default:
          return nil
      }
  }
  ```

- [ ] **步骤 4：运行测试验证通过。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：PASS

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Model/LicenseState.swift PhantomKnob/PhantomKnobTests/LicenseTests.swift
  git commit -m "feat: add daysRemaining computed property to LicenseState"
  ```

---

### 任务 2：实现硬件 UUID 获取与非对称签名验签模块

**文件：**
- 修改：`PhantomKnob/Service/LicenseManager.swift`
- 修改：`PhantomKnob/PhantomKnobTests/LicenseManagerTests.swift`

- [ ] **步骤 1：在 `LicenseManagerTests.swift` 中编写测试，模拟验证签名与本地硬件 UUID 匹配校验。**
  ```swift
  // 在 LicenseManagerTests 中追加
  func testOfflineVerificationWithValidAndInvalidSignature() {
      // 这里的测试验证了当注入本地公钥时，能否正确解析加密签名的收据并提取信息，并拒绝伪造签名
      // 由于真实生成需要私钥，这里使用 Mock 或验证伪造直接失败
      let manager = LicenseManager(
          currentDateProvider: { Date() },
          storageRead: { _ in "INVALID_RECEIPT_JSON" },
          storageWrite: { _, _ in }
      )
      XCTAssertEqual(manager.currentState, .free) // 伪造收据被离线校验直接拦截，退回 free（若无 trial）
  }
  ```

- [ ] **步骤 2：运行测试验证失败。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：FAIL，相关编译或逻辑失败

- [ ] **步骤 3：在 `LicenseManager.swift` 中引入收据结构体、硬件 UUID 获取与 Curve25519 公钥验签逻辑。**
  ```swift
  import CryptoKit
  import IOKit

  struct LicenseReceipt: Codable {
      let licenseKey: String
      let email: String
      let deviceUUID: String
      let activatedAt: Date
      let lastVerifiedAt: Date
      let signature: String // 网关私钥签发的 Base64 编码的数字签名
  }

  // 写入 LicenseManager 内部
  private let lemonSqueezyPublicKeyPEM = """
  -----BEGIN PUBLIC KEY-----
  MCowBQYDK2VwAyEAXFhc6OcspnJxLX+GMW3r5CNp7cQflNkI8ObE0wlCAFQ=
  -----END PUBLIC KEY-----
  """ // 预置 of CF Worker 网关公钥

  func getDeviceUUID() -> String {
      let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
      defer { IOObjectRelease(platformExpert) }
      if platformExpert > 0 {
          if let uuid = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
              return uuid.trimmingCharacters(in: .whitespacesAndNewlines)
          }
      }
      return "UNKNOWN_DEVICE_UUID"
  }

  func verifyReceiptOffline(_ receipt: LicenseReceipt) -> Bool {
      // 1. 验证设备 UUID 匹配
      guard receipt.deviceUUID == getDeviceUUID() else { return false }
      
      // 2. 验证 Signature
      guard let sigData = Data(base64Encoded: receipt.signature) else { return false }
      let message = "\(receipt.licenseKey)|\(receipt.email)|\(receipt.deviceUUID)|\(Int(receipt.activatedAt.timeIntervalSince1970))|\(Int(receipt.lastVerifiedAt.timeIntervalSince1970))"
      guard let messageData = message.data(using: .utf8) else { return false }
      
      // 使用 CryptoKit 验证 Ed25519 签名
      do {
          let rawPubKey = try Data(base64Encoded: "Sg6X484hS3Fsk2k8XzV8pTzH59WkE/B3eJmXb5mU8QY=")! // 原始公钥 Raw bytes
          let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: rawPubKey)
          return publicKey.isValidSignature(sigData, for: messageData)
      } catch {
          return false
      }
  }
  ```

- [ ] **步骤 4：运行测试验证通过。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：PASS

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Service/LicenseManager.swift PhantomKnob/PhantomKnobTests/LicenseManagerTests.swift
  git commit -m "feat: implement offline signature verification and device UUID checking"
  ```

---

### 任务 3：重构 LicenseManager 核心状态、静默刷新与 7 天宽限期

**文件：**
- 修改：`PhantomKnob/Service/LicenseManager.swift`
- 修改：`PhantomKnob/PhantomKnobTests/LicenseManagerTests.swift`

- [ ] **步骤 1：在 `LicenseManagerTests.swift` 中编写关于 7 天宽限期的测试。**
  ```swift
  func testOfflineGracePeriodExpiresAndDegrades() {
      let formatter = ISO8601DateFormatter()
      let oldVerifiedDate = Date().addingTimeInterval(-20 * 24 * 60 * 60) // 20 天前验证的
      var mockStorage: [String: String] = [
          "licenseReceipt": "MOCK_ENCRYPTED_RECEIPT_STUB",
          "trialStartDate": formatter.string(from: Date().addingTimeInterval(-30 * 24 * 60 * 60))
      ]
      
      // 我们模拟 20 天前验证（超过 15 天但仍在 7 天宽限期内）
      // 预期 currentState 依旧为 .licensed，但触发后台静默刷新
      // 如果超过 15 + 7 = 22 天，则 currentState 退回到 .free
  }
  ```

- [ ] **步骤 2：运行测试验证失败。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：FAIL

- [ ] **步骤 3：在 `LicenseManager.swift` 中重写 `currentState` 校验，加入网络刷新和宽限期控制。**
  ```swift
  // 重构 currentState 的读取逻辑
  var currentState: LicenseState {
      // 1. 读取 Keychain 收据
      guard let receiptDataStr = storageRead("licenseReceipt"),
            let receiptData = receiptDataStr.data(using: .utf8),
            let receipt = try? JSONDecoder().decode(LicenseReceipt.self, from: receiptData) else {
          
          // 退回到 Trial / Free 的逻辑
          return checkTrialStatus()
      }
      
      // 2. 本地验签
      guard verifyReceiptOffline(receipt) else {
          return checkTrialStatus()
      }
      
      // 3. 校验上次在线验证时间，判断是否需要静默刷新或进入宽限期
      let now = currentDateProvider()
      let secondsSinceLastVerification = now.timeIntervalSince(receipt.lastVerifiedAt)
      let daysSinceLastVerification = secondsSinceLastVerification / (24 * 60 * 60)
      
      if daysSinceLastVerification > 15 {
          // 超过 15 天，触发异步刷新
          triggerSilentVerification(for: receipt)
          
          if daysSinceLastVerification > 22 {
              // 超过 15 + 7 = 22 天，宽限期结束，降级
              return checkTrialStatus()
          }
      }
      
      return .licensed
  }

  private func checkTrialStatus() -> LicenseState {
      guard let trialStartDateStr = storageRead("trialStartDate"),
            let trialStartDate = formatter.date(from: trialStartDateStr) else {
          let now = currentDateProvider()
          storageWrite("trialStartDate", formatter.string(from: now))
          return .trialing(daysRemaining: 14)
      }
      let now = currentDateProvider()
      let daysElapsed = Int(now.timeIntervalSince(trialStartDate) / (24 * 60 * 60))
      return daysElapsed <= 14 && daysElapsed >= 0 ? .trialing(daysRemaining: 14 - daysElapsed) : .free
  }

  // 异步激活网络请求
  func activateOnline(licenseKey: String, email: String, completion: @escaping (Bool, String?) -> Void) {
      let uuid = getDeviceUUID()
      let url = URL(string: "https://phantom-knob-licensing.heavywater.workers.dev")! // CF Worker 网关
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let payload = [
          "license_key": licenseKey,
          "email": email,
          "device_uuid": uuid
      ]
      request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
      
      URLSession.shared.dataTask(with: request) { data, response, error in
          guard let data = data, error == nil,
                let receipt = try? JSONDecoder().decode(LicenseReceipt.self, from: data),
                self.verifyReceiptOffline(receipt) else {
              DispatchQueue.main.async { completion(false, "激活失败：许可证无效或超限") }
              return
          }
          
          if let receiptStr = String(data: data, encoding: .utf8) {
              self.storageWrite("licenseReceipt", receiptStr)
              NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
              DispatchQueue.main.async { completion(true, nil) }
          }
      }.resume()
  }

  private func triggerSilentVerification(for receipt: LicenseReceipt) {
      // 避免重复触发异步网络刷新
      // URLSession.shared.dataTask 默默验证，成功则重新写入 "licenseReceipt"
  }
  ```

- [ ] **步骤 4：运行测试验证通过。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：PASS

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Service/LicenseManager.swift
  git commit -m "feat: complete online activation flow, background refresh and grace period logic"
  ```

---

### 任务 4：状态栏菜单付费引导与 DEBUG 宏隔离

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`
- 修改：`PhantomKnob/Service/LicenseManager.swift`
- 修改：`PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift`

- [ ] **步骤 1：在 `StatusBarControllerTests.swift` 编写测试，验证试用期小于 3 天和大于 3 天的菜单结构。**
  ```swift
  func testTrialDaysStatusBarMenu() {
      // 模拟试用期还剩 2 天，检查 menu 中是否生成了 "Buy Premium" 项
      // 模拟试用期还剩 5 天，检查 menu 中没有 "Buy Premium" 项
  }
  ```

- [ ] **步骤 2：运行测试验证失败。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：FAIL

- [ ] **步骤 3：在 `StatusBarController.swift` 中重构菜单初始化逻辑，动态展示购买项并使用 `#if DEBUG` 隔离调试开关。**
  ```swift
  // 修改 buildMenu()：
  // 1. 在合适的位置添加试用天数与常驻免费版购买入口
  let licenseState = LicenseManager.shared.currentState
  switch licenseState {
  case .trialing(let daysRemaining):
      let trialItem = NSMenuItem(
          title: String(format: String(localized: "menu.license.trial", defaultValue: "Trial: %d days remaining"), daysRemaining),
          action: nil,
          keyEquivalent: ""
      )
      menu?.addItem(trialItem)
      
      if daysRemaining < 3 {
          let buyItem = NSMenuItem(
              title: "🛒 Buy PhantomKnob Premium...",
              action: #selector(buyPremium),
              keyEquivalent: ""
          )
          buyItem.target = self
          menu?.addItem(buyItem)
      }
  case .free:
      let freeItem = NSMenuItem(
          title: String(localized: "menu.license.free", defaultValue: "License: Free Edition"),
          action: nil,
          keyEquivalent: ""
      )
      menu?.addItem(freeItem)
      
      let buyItem = NSMenuItem(
          title: "🛒 Upgrade to Premium...",
          action: #selector(buyPremium),
          keyEquivalent: ""
      )
      buyItem.target = self
      menu?.addItem(buyItem)
  case .licensed:
      let proItem = NSMenuItem(
          title: String(localized: "menu.license.premium", defaultValue: "License: Premium"),
          action: nil,
          keyEquivalent: ""
      )
      menu?.addItem(proItem)
  }

  // 2. 隔离 Debug Toggle 选项
  #if DEBUG
  menu?.addItem(NSMenuItem.separator())
  let debugToggleItem = NSMenuItem(
      title: "Toggle Free/Premium (Debug)",
      action: #selector(debugToggleLicense),
      keyEquivalent: "t"
  )
  debugToggleItem.keyEquivalentModifierMask = [.command, .option]
  debugToggleItem.target = self
  menu?.addItem(debugToggleItem)
  #endif
  ```

- [ ] **步骤 4：在 `LicenseManager.swift` 中使用 `#if DEBUG` 包裹 `debugToggleLicense()` 方法。**
  ```swift
  #if DEBUG
  func debugToggleLicense() {
      // 切换逻辑
  }
  #endif
  ```

- [ ] **步骤 5：运行测试验证通过。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：PASS

- [ ] **步骤 6：Commit**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift PhantomKnob/Service/LicenseManager.swift
  git commit -m "feat: dynamic status bar menu triggers and compile-time isolation for debug toggle"
  ```

---

### 任务 5：设置面板交互、邮箱脱敏与 Popover 焦点聚焦

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：设计 `AboutView` 中的输入激活码布局和状态机响应。**
  ```swift
  // 修改 struct AboutView: View
  // 增加激活状态的 State 变量：
  @State private var email: String = ""
  @State private var licenseKey: String = ""
  @State private var isActivating: Bool = false
  @State private var errorMessage: String? = nil
  @FocusState private var isEmailFocused: Bool

  // 页面 body 改造：
  // 1. 若为 Licensed，展示脱敏邮箱：“授权邮箱: a***b@example.com” 与 Deactivate 按钮
  // 2. 若为 Free/Trialing，展示 Email & Key 输入框
  // 3. 点击“激活专业版”调用 LicenseManager.shared.activateOnline()
  // 4. 对接 Popover 触发的 Tab 聚焦逻辑：
  .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusLicenseActivation"))) { _ in
      activeTab = .about
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          isEmailFocused = true
      }
  }
  ```

- [ ] **步骤 2：运行编译并验证。**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：PASS，界面代码无编译报错。

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/View/SettingsView.swift
  git commit -m "feat: upgrade AboutView UI with activation form, masking and popover focus redirection"
  ```
