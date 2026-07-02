# Phase 1：基础产品化 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 完成 PhantomKnob 从开发原型到可分发付费产品的硬阻塞项——签名公证、图标、英文化、许可证、Feature Gating、落地页、DMG。

**架构：** 在现有代码库上增加 LicenseManager（许可证状态管理）和 FeatureGate（功能分层判断）两个核心模块，改造 KnobStateManager 支持会话限时，改造所有 View 文件使用 String Catalog 本地化。

**技术栈：** Swift 5.9 / macOS 13+ / XcodeGen / Paddle macOS SDK / Keychain Services

**规格文档：** `docs/specs/2026-07-02-productization-roadmap.md`

---

## 文件结构总览

**新建文件：**
| 文件 | 职责 |
|---|---|
| `PhantomKnob/Model/LicenseState.swift` | 许可证状态枚举和 Feature 枚举 |
| `PhantomKnob/Service/LicenseManager.swift` | 许可证管理单例（试用期、激活、验证） |
| `PhantomKnob/Service/FeatureGate.swift` | 功能分层判断工具类 |
| `PhantomKnob/Localizable.xcstrings` | String Catalog（英文 + 中文） |
| `PhantomKnob/Assets.xcassets/AppIcon.appiconset/` | App 图标资产 |
| `PhantomKnobTests/LicenseManagerTests.swift` | 许可证系统测试 |
| `PhantomKnobTests/FeatureGateTests.swift` | 功能分层测试 |
| `scripts/create_dmg.sh` | DMG 打包脚本 |
| `website/` | 落地页源码 |

**修改文件：**
| 文件 | 改动 |
|---|---|
| `PhantomKnob/project.yml` | 启用 Hardened Runtime |
| `PhantomKnob/PhantomKnob.entitlements` | 添加必要 entitlements |
| `PhantomKnob/Info.plist` | 开发语言改为 en |
| `PhantomKnob/App/PhantomKnobApp.swift` | 初始化 LicenseManager |
| `PhantomKnob/Service/KnobStateManager.swift` | 添加会话计时器和延迟激活 |
| `PhantomKnob/Service/StatusBarController.swift` | 显示 Free 标志和倒计时 |
| `PhantomKnob/Service/OverlayController.swift` | 根据许可状态限制样式定制 |
| `PhantomKnob/View/SettingsView.swift` | 字符串本地化 + 许可证 UI |
| `PhantomKnob/View/UserGuideView.swift` | 字符串本地化 |
| `PhantomKnob/View/CustomizerHUDView.swift` | 字符串本地化 + 样式锁定 |
| `PhantomKnob/View/OverlayView.swift` | 字符串本地化 |
| `PhantomKnob/View/KnobPanelView.swift` | 字符串本地化 |
| `scripts/build_notarize.sh` | 适配 Hardened Runtime |

---

## 任务 1：Hardened Runtime 与代码签名

**文件：**
- 修改：`PhantomKnob/project.yml:49`
- 修改：`PhantomKnob/PhantomKnob.entitlements`
- 修改：`scripts/build_notarize.sh`

- [ ] **步骤 1：在 project.yml 中启用 Hardened Runtime**

```yaml
# PhantomKnob/project.yml — 修改 settings.base 部分
settings:
  base:
    ENABLE_HARDENED_RUNTIME: YES
```

- [ ] **步骤 2：添加必要的 entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

- [ ] **步骤 3：重新生成 Xcode 项目并构建**

运行：
```bash
cd PhantomKnob && xcodegen generate && xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnob -configuration Release build
```
预期：构建成功，无签名错误

- [ ] **步骤 4：验证 CGEvent 注入功能**

手动测试：
1. 构建并运行 App
2. 按 ⌘⌥R 激活
3. 在 System Settings > Sound 的音量滑块上测试 scroll wheel 翻译
4. 在 QuickTime Player 中测试 arrow key 翻译
5. 确认手势检测、目标检测、Overlay 显示均正常

如果 CGEvent 注入失败，需在 entitlements 中尝试添加：
```xml
<key>com.apple.security.temporary-exception.apple-events</key>
<array>
    <string>com.apple.systemevents</string>
</array>
```

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/project.yml PhantomKnob/PhantomKnob.entitlements
git commit -m "build: enable Hardened Runtime and add automation entitlements"
```

---

## 任务 2：App 图标与资产配置

**文件：**
- 创建：`PhantomKnob/Assets.xcassets/AppIcon.appiconset/Contents.json`
- 创建：`PhantomKnob/Assets.xcassets/AppIcon.appiconset/*.png`

- [ ] **步骤 1：生成 App 图标**

使用图像生成工具创建 1024×1024 App 图标。概念：深色背景上的精致旋钮 dial，macOS 圆角矩形风格。

- [ ] **步骤 2：创建 AppIcon.appiconset/Contents.json**

```json
{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_64.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **步骤 3：使用 sips 从 1024 源图生成所有尺寸**

```bash
cd PhantomKnob/Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512; do
  sips -z $size $size icon_1024.png --out icon_${size}.png
done
```

- [ ] **步骤 4：验证构建并确认图标显示**

运行：`xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnob build`
预期：构建成功，App 在 Finder/Dock 中显示自定义图标

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: add app icon assets"
```

---

## 任务 3：英文本地化基础设施

**文件：**
- 创建：`PhantomKnob/Localizable.xcstrings`
- 修改：`PhantomKnob/Info.plist`
- 修改：`PhantomKnob/project.yml`
- 修改：所有 View 和 Service 文件中的硬编码字符串

### 子任务 3a：建立 String Catalog 基础设施

- [ ] **步骤 1：更新 Info.plist 开发语言为英文**

```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
```

- [ ] **步骤 2：在 project.yml 中添加本地化配置**

在 `options:` 下添加：
```yaml
options:
  defaultLang: en
```

在 target sources 中添加 xcstrings 文件：
```yaml
sources:
  - path: Localizable.xcstrings
```

- [ ] **步骤 3：创建初始 String Catalog 文件**

```json
{
  "sourceLanguage" : "en",
  "strings" : {},
  "version" : "1.0"
}
```

- [ ] **步骤 4：Commit 基础设施**

```bash
git add PhantomKnob/Info.plist PhantomKnob/project.yml PhantomKnob/Localizable.xcstrings
git commit -m "feat: set up String Catalog localization infrastructure (en + zh-Hans)"
```

### 子任务 3b：逐文件本地化

- [ ] **步骤 5：本地化 StatusBarController.swift**（~15 strings）

替换模式：
```swift
// 替换前：
NSMenuItem(title: "状态：未激活", ...)
// 替换后：
NSMenuItem(title: String(localized: "status.inactive", defaultValue: "Status: Inactive"), ...)

// 替换前：
"使用引导..."
// 替换后：
String(localized: "menu.userGuide", defaultValue: "User Guide…")

// 替换前：
"切换控制模式"
// 替换后：
String(localized: "menu.toggleMode", defaultValue: "Toggle Knob Mode")

// 替换前：
"设置..."
// 替换后：
String(localized: "menu.settings", defaultValue: "Settings…")

// 替换前：
"退出"
// 替换后：
String(localized: "menu.quit", defaultValue: "Quit")
```

同样处理 `createTooltip` 和 `stateDescription` 方法中的所有字符串。

- [ ] **步骤 6：Commit**
```bash
git commit -m "i18n: localize StatusBarController strings"
```

- [ ] **步骤 7：本地化 SettingsView.swift**（~25 strings）
- [ ] **步骤 8：本地化 UserGuideView.swift**（~40 strings）
- [ ] **步骤 9：本地化 CustomizerHUDView.swift**（~60 strings）
- [ ] **步骤 10：本地化 OverlayView.swift**（~10 strings）
- [ ] **步骤 11：本地化 KnobPanelView.swift**（~10 strings）
- [ ] **步骤 12：本地化其他 Service/Model 文件**（~20 strings）

每个文件完成后立即 commit。

### 子任务 3c：填写中文翻译

- [ ] **步骤 13：在 String Catalog 中为所有 key 填写 zh-Hans 翻译**

- [ ] **步骤 14：构建并验证双语切换**

运行：系统语言切换到中文 → 启动 App → 确认全中文。切回英文 → 确认全英文。

- [ ] **步骤 15：Commit**
```bash
git commit -m "i18n: complete zh-Hans translations for all localized strings"
```

---

## 任务 4：许可证系统

**文件：**
- 创建：`PhantomKnob/Model/LicenseState.swift`
- 创建：`PhantomKnob/Service/LicenseManager.swift`
- 创建：`PhantomKnobTests/LicenseManagerTests.swift`
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`

### 子任务 4a：LicenseState 模型

- [ ] **步骤 1：编写 LicenseState 测试**

```swift
// PhantomKnobTests/LicenseManagerTests.swift
import XCTest
@testable import PhantomKnob

final class LicenseStateTests: XCTestCase {
    func testTrialStateReportsCorrectDays() {
        let state = LicenseState.trial(daysRemaining: 10)
        XCTAssertTrue(state.isTrial)
        XCTAssertFalse(state.isFree)
        XCTAssertFalse(state.isLicensed)
        XCTAssertEqual(state.trialDaysRemaining, 10)
    }

    func testFreeStateAfterTrialExpiry() {
        let state = LicenseState.free
        XCTAssertFalse(state.isTrial)
        XCTAssertTrue(state.isFree)
        XCTAssertEqual(state.trialDaysRemaining, 0)
    }

    func testLicensedState() {
        let state = LicenseState.licensed
        XCTAssertTrue(state.isLicensed)
    }

    func testTrialHasFullAccess() {
        XCTAssertTrue(LicenseState.trial(daysRemaining: 7).hasFullAccess)
    }

    func testFreeHasLimitedAccess() {
        XCTAssertFalse(LicenseState.free.hasFullAccess)
    }

    func testLicensedHasFullAccess() {
        XCTAssertTrue(LicenseState.licensed.hasFullAccess)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnobTests`
预期：FAIL — LicenseState 未定义

- [ ] **步骤 3：实现 LicenseState**

```swift
// PhantomKnob/Model/LicenseState.swift
import Foundation

enum LicenseState: Equatable {
    case trial(daysRemaining: Int)
    case free
    case licensed

    var isTrial: Bool {
        if case .trial = self { return true }
        return false
    }

    var isFree: Bool {
        if case .free = self { return true }
        return false
    }

    var isLicensed: Bool {
        if case .licensed = self { return true }
        return false
    }

    var trialDaysRemaining: Int {
        if case .trial(let days) = self { return days }
        return 0
    }

    /// Trial 和 Licensed 都拥有完整访问权限
    var hasFullAccess: Bool {
        switch self {
        case .trial, .licensed: return true
        case .free: return false
        }
    }

    var canCustomizeOverlay: Bool { hasFullAccess }
    var requiresActivationDelay: Bool { !hasFullAccess }

    var sessionDurationLimit: TimeInterval? {
        hasFullAccess ? nil : 15 * 60
    }
}

enum PremiumFeature {
    case overlayCustomization
    case instantActivation
    case unlimitedSession
    case iCloudSync
    case ruleExport
}
```

- [ ] **步骤 4：运行测试验证通过**
- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Model/LicenseState.swift PhantomKnobTests/LicenseManagerTests.swift
git commit -m "feat: add LicenseState model with trial/free/licensed states"
```

### 子任务 4b：LicenseManager 单例

- [ ] **步骤 6：编写 LicenseManager 测试**

```swift
final class LicenseManagerTests: XCTestCase {
    var manager: LicenseManager!

    override func setUp() {
        super.setUp()
        manager = LicenseManager(userDefaults: UserDefaults(suiteName: "test.license")!)
        manager.userDefaults.removePersistentDomain(forName: "test.license")
    }

    func testFirstLaunchStartsTrial() {
        manager.initialize()
        XCTAssertTrue(manager.state.isTrial)
        XCTAssertEqual(manager.state.trialDaysRemaining, 14)
    }

    func testTrialExpiresAfter14Days() {
        let installDate = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        manager.userDefaults.set(installDate, forKey: LicenseManager.installDateKey)
        manager.initialize()
        XCTAssertTrue(manager.state.isFree)
    }

    func testActivationSetsLicensedState() {
        manager.initialize()
        manager.activateWithKey("TEST-KEY")
        XCTAssertTrue(manager.state.isLicensed)
    }

    func testDeactivationReturnsToPreviousState() {
        manager.initialize()
        manager.activateWithKey("TEST-KEY")
        manager.deactivate()
        XCTAssertFalse(manager.state.isLicensed)
    }
}
```

- [ ] **步骤 7：实现 LicenseManager**

```swift
// PhantomKnob/Service/LicenseManager.swift
import Foundation
import Combine

final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    static let installDateKey = "com.phantomknob.installDate"
    static let licenseKeyKey = "com.phantomknob.licenseKey"
    static let trialDuration = 14

    @Published private(set) var state: LicenseState = .free
    internal var userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func initialize() {
        if let key = userDefaults.string(forKey: Self.licenseKeyKey), !key.isEmpty {
            state = .licensed
            return
        }
        if let installDate = userDefaults.object(forKey: Self.installDateKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
            let remaining = max(0, Self.trialDuration - days)
            state = remaining > 0 ? .trial(daysRemaining: remaining) : .free
        } else {
            userDefaults.set(Date(), forKey: Self.installDateKey)
            state = .trial(daysRemaining: Self.trialDuration)
        }
    }

    func activateWithKey(_ key: String) {
        userDefaults.set(key, forKey: Self.licenseKeyKey)
        state = .licensed
    }

    func deactivate() {
        userDefaults.removeObject(forKey: Self.licenseKeyKey)
        initialize()
    }
}
```

- [ ] **步骤 8：运行测试验证通过**
- [ ] **步骤 9：集成到 App 启动流程**

在 `PhantomKnobApp.swift` 的 `AppState.init()` 中添加：
```swift
LicenseManager.shared.initialize()
```

- [ ] **步骤 10：Commit**

```bash
git add PhantomKnob/Service/LicenseManager.swift PhantomKnob/App/PhantomKnobApp.swift PhantomKnobTests/LicenseManagerTests.swift
git commit -m "feat: implement LicenseManager with trial tracking and activation"
```

---

## 任务 5：Feature Gating 摩擦机制

**文件：**
- 创建：`PhantomKnob/Service/FeatureGate.swift`
- 创建：`PhantomKnobTests/FeatureGateTests.swift`
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/Service/StatusBarController.swift`
- 修改：`PhantomKnob/Service/OverlayController.swift`

### 子任务 5a：FeatureGate

- [ ] **步骤 1：编写测试**

```swift
// PhantomKnobTests/FeatureGateTests.swift
import XCTest
@testable import PhantomKnob

final class FeatureGateTests: XCTestCase {
    func testTrialUserFullAccess() {
        let gate = FeatureGate(licenseState: .trial(daysRemaining: 7))
        XCTAssertTrue(gate.isUnlocked(.overlayCustomization))
        XCTAssertEqual(gate.activationDelay, 0.0)
        XCTAssertNil(gate.sessionDurationLimit)
    }

    func testFreeUserRestrictions() {
        let gate = FeatureGate(licenseState: .free)
        XCTAssertFalse(gate.isUnlocked(.overlayCustomization))
        XCTAssertEqual(gate.activationDelay, 2.0)
        XCTAssertEqual(gate.sessionDurationLimit, 15 * 60)
    }

    func testLicensedUserFullAccess() {
        let gate = FeatureGate(licenseState: .licensed)
        XCTAssertTrue(gate.isUnlocked(.unlimitedSession))
        XCTAssertEqual(gate.activationDelay, 0.0)
        XCTAssertNil(gate.sessionDurationLimit)
    }
}
```

- [ ] **步骤 2：实现 FeatureGate**

```swift
// PhantomKnob/Service/FeatureGate.swift
import Foundation

struct FeatureGate {
    let licenseState: LicenseState

    static var current: FeatureGate {
        FeatureGate(licenseState: LicenseManager.shared.state)
    }

    func isUnlocked(_ feature: PremiumFeature) -> Bool {
        licenseState.hasFullAccess
    }

    var activationDelay: TimeInterval {
        licenseState.requiresActivationDelay ? 2.0 : 0.0
    }

    var sessionDurationLimit: TimeInterval? {
        licenseState.sessionDurationLimit
    }
}
```

- [ ] **步骤 3：运行测试验证通过**
- [ ] **步骤 4：Commit**

### 子任务 5b：KnobStateManager 延迟激活 + 会话限时

- [ ] **步骤 5：添加属性**

在 KnobStateManager 中添加：
```swift
private var sessionTimer: Timer?
private var sessionStartTime: Date?
private var activationDelayTimer: Timer?
```

- [ ] **步骤 6：修改 toggleMode() 中 inactive→activated 转换**

```swift
// 替换 transition(to: .activated) 和 startMultitouch() 为：
let delay = FeatureGate.current.activationDelay
if delay > 0 {
    activationDelayTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
        self?.completeActivation()
    }
} else {
    completeActivation()
}
```

- [ ] **步骤 7：添加 completeActivation() 和 updateSessionCountdown()**

```swift
private func completeActivation() {
    transition(to: .activated)
    startMultitouch()
    if let limit = FeatureGate.current.sessionDurationLimit {
        sessionStartTime = Date()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionCountdown()
        }
    }
}

private func updateSessionCountdown() {
    guard let start = sessionStartTime,
          let limit = FeatureGate.current.sessionDurationLimit else { return }
    let remaining = limit - Date().timeIntervalSince(start)
    if remaining <= 0 {
        sessionTimer?.invalidate()
        sessionTimer = nil
        sessionStartTime = nil
        transition(to: .inactive)
        stopMultitouch()
    }
    statusBarController.updateSessionCountdown(remaining: max(0, remaining))
}
```

- [ ] **步骤 8：在 transition(to: .inactive) 时清理计时器**
- [ ] **步骤 9：Commit**

### 子任务 5c：StatusBarController 倒计时

- [ ] **步骤 10：添加 updateSessionCountdown 方法和菜单 Upgrade 入口**
- [ ] **步骤 11：Commit**

### 子任务 5d：Overlay 样式锁定

- [ ] **步骤 12：OverlayController.show() 中检查 FeatureGate，Free 用户强制默认样式**
- [ ] **步骤 13：Commit**

---

## 任务 6：落地页与 Privacy Policy

**文件：**
- 创建：`website/index.html`
- 创建：`website/privacy.html`
- 创建：`website/terms.html`
- 创建：`website/style.css`

- [ ] **步骤 1：创建落地页** — Hero + 功能 + 定价表 + FAQ + Footer
- [ ] **步骤 2：创建 Privacy Policy**
- [ ] **步骤 3：创建 Terms of Service**
- [ ] **步骤 4：Commit**

---

## 任务 7：DMG 安装器自动化

**文件：**
- 创建：`scripts/create_dmg.sh`
- 修改：`scripts/build_notarize.sh`

- [ ] **步骤 1：创建 DMG 打包脚本**

```bash
#!/bin/bash
# scripts/create_dmg.sh — 依赖：brew install create-dmg
APP_PATH="$1"
DMG_OUTPUT="$2"
create-dmg \
    --volname "PhantomKnob" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "PhantomKnob.app" 175 190 \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_OUTPUT" "$APP_PATH"
```

- [ ] **步骤 2：在 build_notarize.sh 末尾添加 DMG 打包 + 签名 + 公证步骤**
- [ ] **步骤 3：测试 DMG 生成**
- [ ] **步骤 4：Commit**

---

## 验证计划

### 自动化测试
```bash
xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnobTests
```

### 手动验证
1. **Hardened Runtime**：构建后在全新 Mac 上运行，验证所有手势功能正常
2. **本地化**：系统语言切换英文/中文，所有 UI 文案正确
3. **许可证**：首次启动 → 试用(14天) → 过期 → Free → 输入 key → Licensed
4. **Feature Gating**：Free 用户验证 2 秒延迟 + 15 分钟限时 + 固定 Overlay 样式
5. **DMG**：安装器拖拽安装体验正常
