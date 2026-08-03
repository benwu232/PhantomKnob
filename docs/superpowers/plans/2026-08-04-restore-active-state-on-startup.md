# 应用启动时恢复旋钮激活状态 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现当 PhantomKnob 启动时根据用户设置与上次退出时的状态，自动恢复旋钮激活状态（.activated）。

**架构：** 在应用全局切换激活状态时持久化 `lastKnobActiveState` 状态，在通用设置中提供 `restoreActiveStateOnStartup` 开关（默认开）。应用启动时在 `KnobStateManager.start()` 中依据开关、历史状态与辅助功能权限，决定是否自动开启旋钮激活模式。

**技术栈：** Swift, SwiftUI, AppKit, XCTest, UserDefaults, Combine

---

### 文件结构

1. **`PhantomKnob/Storage/UserDefaults+App.swift`**
   - 增加常用 UserDefaults 键与便捷扩展属性（`restoreActiveStateOnStartup` 和 `lastKnobActiveState`）。
2. **`PhantomKnob/Service/KnobStateManager.swift`**
   - 在 `transition(to:)` 中添加 `lastKnobActiveState` 状态写入逻辑（避开 Option 临时 hold 模式）。
   - 在 `start()` 中添加启动条件判断，满足条件且授权通过时恢复激活。
3. **`PhantomKnob/View/SettingsView.swift`**
   - 在 `GeneralSettingsView` 添加“启动时恢复激活状态”切换开关及其绑定。
4. **`PhantomKnob/Localizable.xcstrings`**
   - 新增 `settings.general.restoreActiveState` 的多语言（中文与英文）文案。
5. **`PhantomKnob/PhantomKnobTests/KnobActiveStatePersistenceTests.swift`**
   - 新建单元测试文件，涵盖持久化读写测试与启动自动恢复激活模式测试。

---

### 任务 1：创建单元测试与 UserDefaults 状态扩展

**文件：**
- 修改：`PhantomKnob/Storage/UserDefaults+App.swift`
- 创建：`PhantomKnob/PhantomKnobTests/KnobActiveStatePersistenceTests.swift`

- [ ] **步骤 1：在 `UserDefaults+App.swift` 中添加状态与设置属性扩展**

```swift
// PhantomKnob/Storage/UserDefaults+App.swift
import Foundation

extension UserDefaults {
    private static var _app: UserDefaults = .standard
    
    /// The UserDefaults instance to be used across the application.
    /// Defaults to `.standard`, but can be redirected to an isolated suite in unit tests.
    public static var app: UserDefaults {
        get { _app }
        set { _app = newValue }
    }

    /// Whether to restore the active state of PhantomKnob on application startup.
    public var restoreActiveStateOnStartup: Bool {
        get { object(forKey: "restoreActiveStateOnStartup") as? Bool ?? true }
        set { set(newValue, forKey: "restoreActiveStateOnStartup") }
    }

    /// The last persistent active state of PhantomKnob.
    public var lastKnobActiveState: Bool {
        get { bool(forKey: "lastKnobActiveState") }
        set { set(newValue, forKey: "lastKnobActiveState") }
    }
}
```

- [ ] **步骤 2：编写失败的持久化测试框架**

创建 `PhantomKnob/PhantomKnobTests/KnobActiveStatePersistenceTests.swift`：

```swift
import XCTest
@testable import PhantomKnob

class KnobActiveStatePersistenceTests: XCTestCase {
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "KnobActiveStatePersistenceTests_\(UUID().uuidString)")!
        UserDefaults.app = testDefaults
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil
        UserDefaults.app = .standard
        super.tearDown()
    }

    func testUserDefaultsDefaultValues() {
        XCTAssertTrue(UserDefaults.app.restoreActiveStateOnStartup)
        XCTAssertFalse(UserDefaults.app.lastKnobActiveState)
    }

    func testUserDefaultsPropertyMutations() {
        UserDefaults.app.restoreActiveStateOnStartup = false
        XCTAssertFalse(UserDefaults.app.restoreActiveStateOnStartup)

        UserDefaults.app.lastKnobActiveState = true
        XCTAssertTrue(UserDefaults.app.lastKnobActiveState)
    }
}
```

- [ ] **步骤 3：运行单元测试**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/KnobActiveStatePersistenceTests`
预期：PASS

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/Storage/UserDefaults+App.swift PhantomKnob/PhantomKnobTests/KnobActiveStatePersistenceTests.swift
git commit -m "feat: add UserDefaults extension for knob active state persistence"
```

---

### 任务 2：实现 KnobStateManager 中的状态持久化与启动自动恢复

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/PhantomKnobTests/KnobActiveStatePersistenceTests.swift`

- [ ] **步骤 1：在 `KnobActiveStatePersistenceTests.swift` 中添加测试用例**

修改 `PhantomKnob/PhantomKnobTests/KnobActiveStatePersistenceTests.swift`，增加对 `KnobStateManager` 状态切换持久化与 `start()` 自动恢复逻辑的测试：

```swift
    func testStateTransitionUpdatesLastKnobActiveState() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { true }

        XCTAssertFalse(UserDefaults.app.lastKnobActiveState)

        // 切换到 activated 状态
        manager.toggleMode()
        XCTAssertEqual(manager.state, .activated)
        XCTAssertTrue(UserDefaults.app.lastKnobActiveState)

        // 切换到 inactive 状态
        manager.toggleMode()
        XCTAssertEqual(manager.state, .inactive)
        XCTAssertFalse(UserDefaults.app.lastKnobActiveState)
    }

    func testStartRestoresActivatedStateWhenEnabled() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        UserDefaults.app.restoreActiveStateOnStartup = true
        UserDefaults.app.lastKnobActiveState = true

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { true }

        manager.start()
        XCTAssertEqual(manager.state, .activated)
    }

    func testStartDoesNotRestoreWhenSettingDisabled() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        UserDefaults.app.restoreActiveStateOnStartup = false
        UserDefaults.app.lastKnobActiveState = true

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { true }

        manager.start()
        XCTAssertEqual(manager.state, .inactive)
    }

    func testStartDoesNotRestoreWhenNotTrusted() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        UserDefaults.app.restoreActiveStateOnStartup = true
        UserDefaults.app.lastKnobActiveState = true

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { false }

        manager.start()
        XCTAssertEqual(manager.state, .inactive)
    }
```

- [ ] **步骤 2：运行测试验证新增用例失败**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/KnobActiveStatePersistenceTests`
预期：FAIL（`testStateTransitionUpdatesLastKnobActiveState` 与 `testStartRestoresActivatedStateWhenEnabled` 失败，因为 `KnobStateManager` 尚未加入持久化与自动恢复逻辑）。

- [ ] **步骤 3：在 `KnobStateManager.swift` 中实现状态持久化与启动恢复逻辑**

修改 `KnobStateManager.swift` 中的 `start()` 与 `transition(to:)` 方法：

在 `start()` 方法：
```swift
    func start() {
        statusBarController.updateState(.inactive)
        touchHandler.startMonitoring()

        // 绑定 MultitouchManager 代理
        MultitouchManager.shared.delegate = self

        // 启动时自动恢复激活状态
        if UserDefaults.app.restoreActiveStateOnStartup &&
           UserDefaults.app.lastKnobActiveState &&
           isProcessTrusted() {
            PKLogger.knob.info("Restoring last active state on startup")
            toggleMode()
        }
    }
```

在 `transition(to newState: KnobGlobalState)` 方法中更新持久化：
```swift
    func transition(to newState: KnobGlobalState) {
        let oldState = state
        state = newState
        statusBarController.updateState(newState)
        
        // 避开临时 Option hold 状态，仅更新显式持久化的激活状态
        if !isOptionHoldActive && !isOptionHoldInactive {
            if case .activated = newState {
                UserDefaults.app.lastKnobActiveState = true
            } else if case .inactive = newState {
                UserDefaults.app.lastKnobActiveState = false
            }
        }
        
        PKLogger.knob.info("State transition: \(String(describing: oldState)) -> \(String(describing: newState))")
    }
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/KnobActiveStatePersistenceTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Service/KnobStateManager.swift PhantomKnob/PhantomKnobTests/KnobActiveStatePersistenceTests.swift
git commit -m "feat: persist active state in KnobStateManager and restore on startup"
```

---

### 任务 3：在设置界面中添加通用设置开关与多语言配置

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：在 `GeneralSettingsView` 中添加持久化状态恢复开关**

修改 `PhantomKnob/View/SettingsView.swift` 中的 `GeneralSettingsView`：

在 `GeneralSettingsView` 的 `@State` / `@AppStorage` 声明区添加：
```swift
    @AppStorage("restoreActiveStateOnStartup", store: .app) private var restoreActiveStateOnStartup = true
```

在 `VStack(spacing: 14)` 内部添加【通用行为】（General Behavior）卡片：
```swift
            // -- Behavior Section Card --
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "settings.section.behavior", defaultValue: "Behavior"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                }
                
                Toggle(isOn: $restoreActiveStateOnStartup) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.general.restoreActiveState", defaultValue: "Restore activation state on startup"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text(String(localized: "settings.general.restoreActiveState.subtitle", defaultValue: "Automatically resume PhantomKnob if it was active when last quit"))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
```

- [ ] **步骤 2：在 `Localizable.xcstrings` 中添加多语言**

更新 `PhantomKnob/Localizable.xcstrings`，确保包含 `settings.section.behavior`、`settings.general.restoreActiveState` 以及 `settings.general.restoreActiveState.subtitle` 的中文与英文翻译。

- [ ] **步骤 3：编译项目并运行全部单元测试**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS'`
预期：BUILD SUCCEEDED，ALL TESTS PASS

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/View/SettingsView.swift PhantomKnob/Localizable.xcstrings
git commit -m "feat: add restore active state toggle to General Settings UI"
```
