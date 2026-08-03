# 状态栏右键菜单 License 管理入口实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在状态栏右键菜单中，Free 版显示“升级到专业版...”，Pro 版显示“许可管理...”，点击均触发打开 License 窗口。

**架构：** 在 `StatusBarController.swift` 的 `setupMenu()` 中调整按 `licenseState` 渲染动态菜单项逻辑；在 `Localizable.xcstrings` 中添加 `menu.manageLicense` 本地化文案；添加并更新 `StatusBarControllerTests.swift` 单元测试。

**技术栈：** macOS / Swift / AppKit (NSMenu, NSMenuItem) / XCTest

---

## 涉及文件

- 修改：`PhantomKnob/Localizable.xcstrings`
- 修改：`PhantomKnob/Service/StatusBarController.swift:143-166, 542-545`
- 修改：`PhantomKnobTests/StatusBarControllerTests.swift:284-329`

---

## 任务列表

### 任务 1：在 `Localizable.xcstrings` 中增加 `menu.manageLicense` 本地化条目

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：在 `Localizable.xcstrings` 中添加 `menu.manageLicense` 字符串定义**

在 `"strings"` 字典中添加：
```json
    "menu.manageLicense" : {
      "comment" : "Menu item to open license management window for Pro users.",
      "extractionState" : "manual",
      "localizations" : {
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "🔑 许可管理..."
          }
        }
      }
    }
```

- [ ] **步骤 2：Commit**

```bash
git add PhantomKnob/Localizable.xcstrings
git commit -m "feat(i18n): add menu.manageLicense localization string"
```

---

### 任务 2：编写针对 Free 版与 Pro 版菜单项的单元测试（TDD 步骤）

**文件：**
- 修改：`PhantomKnobTests/StatusBarControllerTests.swift`

- [ ] **步骤 1：在 `StatusBarControllerTests.swift` 中编写测试用例 `testLicenseStatusMenuItems()`**

```swift
    func testLicenseStatusMenuItems() {
        let controller = StatusBarController()
        
        let originalKey = UserDefaults.app.string(forKey: "proLicenseKey")
        let originalEmail = UserDefaults.app.string(forKey: "proLicenseEmail")
        let originalTrialStart = UserDefaults.app.string(forKey: "proTrialStartDate")
        
        let formatter = ISO8601DateFormatter()
        let trialStartDateExpired = Date().addingTimeInterval(-20 * 24 * 60 * 60)
        
        // 1. Free 状态：验证包含 Upgrade to Pro / 升级到专业版 菜单项
        UserDefaults.app.removeObject(forKey: "proLicenseKey")
        UserDefaults.app.removeObject(forKey: "proLicenseEmail")
        UserDefaults.app.set(formatter.string(from: trialStartDateExpired), forKey: "proTrialStartDate")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
        controller.rebuildMenu()
        
        let freeMenuItems = controller.menu?.items ?? []
        let hasUpgradeItem = freeMenuItems.contains { $0.action == #selector(StatusBarController.buyPro) }
        XCTAssertTrue(hasUpgradeItem, "Free 模式下应包含升级入口")
        
        // 2. Pro 状态：验证包含 Manage License / 许可管理 菜单项
        UserDefaults.app.set("test-pro-key", forKey: "proLicenseKey")
        UserDefaults.app.set("test@example.com", forKey: "proLicenseEmail")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
        controller.rebuildMenu()
        
        let proMenuItems = controller.menu?.items ?? []
        let hasManageItem = proMenuItems.contains { $0.action == #selector(StatusBarController.buyPro) }
        XCTAssertTrue(hasManageItem, "Pro 模式下应包含许可管理入口")
        
        let manageMenuItem = proMenuItems.first { $0.action == #selector(StatusBarController.buyPro) }
        XCTAssertEqual(manageMenuItem?.title, String(localized: "menu.manageLicense", defaultValue: "🔑 Manage License..."))
        
        // 恢复初始状态
        UserDefaults.app.set(originalKey, forKey: "proLicenseKey")
        UserDefaults.app.set(originalEmail, forKey: "proLicenseEmail")
        UserDefaults.app.set(originalTrialStart, forKey: "proTrialStartDate")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
    }
```

- [ ] **步骤 2：运行单元测试，确认测试由于 Pro 状态下缺少菜单项而失败（RED）**

运行：
```bash
xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/StatusBarControllerTests/testLicenseStatusMenuItems
```
预期：FAIL，报错 "Pro 模式下应包含许可管理入口"（Because `.licensed` currently adds no menu item）。

- [ ] **步骤 3：Commit 测试用例**

```bash
git add PhantomKnobTests/StatusBarControllerTests.swift
git commit -m "test: add unit test for status bar license menu items"
```

---

### 任务 3：更新 `StatusBarController.swift` 中的菜单项构建逻辑

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：更新 `setupMenu()` 中的 `switch licenseState` 分支**

修改 `StatusBarController.swift` 约第 143-165 行：

```swift
        // 动态添加购买/升级/管理 Pro 项目
        let licenseState = LicenseManager.shared.currentState
        switch licenseState {
        case .trialing(let daysRemaining):
            if daysRemaining < 3 {
                let buyItem = NSMenuItem(
                    title: String(localized: "menu.buyPro", defaultValue: "🛒 Buy PhantomKnob Pro..."),
                    action: #selector(buyPro),
                    keyEquivalent: ""
                )
                buyItem.target = self
                menu?.addItem(buyItem)
            }
        case .free:
            let buyItem = NSMenuItem(
                title: String(localized: "menu.upgradeToPro", defaultValue: "🛒 Upgrade to Pro..."),
                action: #selector(buyPro),
                keyEquivalent: ""
            )
            buyItem.target = self
            menu?.addItem(buyItem)
        case .licensed:
            let manageItem = NSMenuItem(
                title: String(localized: "menu.manageLicense", defaultValue: "🔑 Manage License..."),
                action: #selector(buyPro),
                keyEquivalent: ""
            )
            manageItem.target = self
            menu?.addItem(manageItem)
        }
```

- [ ] **步骤 2：重新运行测试，确认测试验证通过（GREEN）**

运行：
```bash
xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/StatusBarControllerTests/testLicenseStatusMenuItems
```
预期：PASS。

- [ ] **步骤 3：运行全量 `StatusBarControllerTests`，确保不破坏现有逻辑**

运行：
```bash
xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/StatusBarControllerTests
```
预期：PASS。

- [ ] **步骤 4：Commit 功能代码与调整**

```bash
git add PhantomKnob/Service/StatusBarController.swift
git commit -m "feat(statusbar): add Manage License menu item for Pro users"
```
