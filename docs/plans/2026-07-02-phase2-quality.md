# Phase 2：品质打磨 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。

**目标：** 提升 PhantomKnob 到"值得付费"的品质水平——崩溃上报、日志治理、品牌图标、Pro App 旋钮包、英文引导、版本管理。

**前置依赖：** Phase 1 全部完成

**规格文档：** `docs/specs/2026-07-02-productization-roadmap.md`

---

## 任务 1：崩溃上报（Sentry）

**文件：**
- 修改：`PhantomKnob/Package.swift`（添加 sentry-cocoa 依赖）
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：通过 SPM 添加 sentry-cocoa 依赖**

在 `Package.swift` 或 `project.yml` 中添加：
```yaml
packages:
  Sentry:
    url: https://github.com/getsentry/sentry-cocoa
    from: "8.0.0"
```

- [ ] **步骤 2：在 AppState.init() 中初始化 Sentry**

```swift
import Sentry

// 在 AppState.init() 最开始：
SentrySDK.start { options in
    options.dsn = "YOUR_SENTRY_DSN"
    options.environment = "production"
    options.sampleRate = 1.0
    options.enableAutoSessionTracking = true
    options.attachStacktrace = true
    // 尊重用户隐私设置
    options.beforeSend = { event in
        let optOut = UserDefaults.standard.bool(forKey: "disableCrashReporting")
        return optOut ? nil : event
    }
}
```

- [ ] **步骤 3：在关键状态转换处添加 breadcrumbs**

```swift
// KnobStateManager.transition() 中：
SentrySDK.addBreadcrumb(Breadcrumb(level: .info, category: "state"))
```

- [ ] **步骤 4：在设置中添加 crash reporting opt-out 开关**

在 SettingsView GeneralSettingsView 中添加：
```swift
Toggle(String(localized: "settings.crashReporting", defaultValue: "Send crash reports"),
       isOn: Binding(
           get: { !UserDefaults.standard.bool(forKey: "disableCrashReporting") },
           set: { UserDefaults.standard.set(!$0, forKey: "disableCrashReporting") }
       ))
```

- [ ] **步骤 5：Commit**

```bash
git commit -m "feat: integrate Sentry crash reporting with opt-out support"
```

---

## 任务 2：日志系统清理

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/Service/StatusBarController.swift`
- 修改：`PhantomKnob/Service/MultitouchManager.swift`
- 修改：`PhantomKnob/Service/OverlayController.swift`
- 修改：`PhantomKnob/Service/GlobalTouchHandler.swift`
- 删除：`debug.log`（从 git 跟踪中移除）

- [ ] **步骤 1：创建统一 Logger 定义**

```swift
// 在 App/ 或 Service/ 中添加 Logger extension
import os

extension Logger {
    static let knob = Logger(subsystem: "com.phantomknob", category: "knob")
    static let license = Logger(subsystem: "com.phantomknob", category: "license")
    static let ui = Logger(subsystem: "com.phantomknob", category: "ui")
}
```

- [ ] **步骤 2：全局替换 writeDebugLog 为 Logger 调用**

涉及文件：KnobStateManager.swift、StatusBarController.swift、MultitouchManager.swift、OverlayController.swift、GlobalTouchHandler.swift

替换模式：
```swift
// 替换前：
writeDebugLog("[KnobStateManager] toggleMode() called")
// 替换后：
Logger.knob.debug("toggleMode() called, current state: \(String(describing: self.state))")
```

- [ ] **步骤 3：删除 writeDebugLog 函数定义**

- [ ] **步骤 4：将 debug.log 添加到 .gitignore 并从 git 中移除**

```bash
echo "debug.log" >> .gitignore
git rm --cached debug.log 2>/dev/null
rm -f debug.log
```

- [ ] **步骤 5：替换所有 NSLog 为 Logger**

```bash
# 查找所有 NSLog 调用
grep -rn "NSLog" PhantomKnob/ --include="*.swift" | grep -v ".build/"
```

- [ ] **步骤 6：验证 Release build 中无 debug 输出**

运行 Release build，确认 Console.app 中无 debug 级别日志。

- [ ] **步骤 7：Commit**

```bash
git commit -m "refactor: replace writeDebugLog and NSLog with structured os.Logger"
```

---

## 任务 3：状态栏品牌图标

**文件：**
- 创建：`PhantomKnob/Assets.xcassets/StatusBar/` (4 个 image set)
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：设计 4 种状态的 template 图标**

每种状态需 18×18pt @1x 和 36×36pt @2x，纯黑色（系统自动适配暗模式）：
- `statusbar_inactive` — 旋钮轮廓
- `statusbar_activated` — 旋钮填充
- `statusbar_knobing` — 旋钮 + 旋转指示线
- `statusbar_cooling` — 旋钮 + 淡化

- [ ] **步骤 2：创建 image set 并添加到 Assets.xcassets**

- [ ] **步骤 3：替换 StatusBarController.createIcon() 中的 SF Symbol**

```swift
private func createIcon(for state: KnobGlobalState) -> NSImage? {
    let name: String
    switch state {
    case .inactive: name = "statusbar_inactive"
    case .activated: name = "statusbar_activated"
    case .knobing, .cooling: name = "statusbar_knobing"
    case .customizing: name = "statusbar_inactive"
    }
    let image = NSImage(named: name)
    image?.isTemplate = true
    return image
}
```

- [ ] **步骤 4：Commit**

```bash
git commit -m "feat: replace SF Symbol status bar icons with branded template images"
```

---

## 任务 4：Pro App 旋钮包

**文件：**
- 创建：`PhantomKnob/Resources/pro-rules/davinci-resolve.json`
- 创建：`PhantomKnob/Resources/pro-rules/final-cut-pro.json`
- 创建：`PhantomKnob/Resources/pro-rules/logic-pro.json`
- 修改：`PhantomKnob/Storage/RuleLibrary.swift`

- [ ] **步骤 1：使用 Accessibility Inspector 调研 DaVinci Resolve 控件**

```bash
# 使用已有工具脚本
swift scripts/inspect_ax_tool.swift "com.blackmagic-design.DaVinciResolve"
```

记录所有可控 AXSlider / AXValueIndicator 元素的 role、identifier、displayName、parentChain。

- [ ] **步骤 2：为 DaVinci Resolve 编写 pro rule JSON**

```json
[
  {
    "key": {
      "bundleID": "com.blackmagic-design.DaVinciResolve",
      "axRole": "AXSlider",
      "displayName": "Lift"
    },
    "configType": "double",
    "doubleConfig": {
      "inner": { "translation": "arrowKeyLeftRight", "unitPerDegree": 0.5, ... },
      "outer": { "translation": "arrowKeyLeftRight", "unitPerDegree": 2.0, ... }
    }
  }
]
```

- [ ] **步骤 3：重复步骤 1-2 for Final Cut Pro 和 Logic Pro**
- [ ] **步骤 4：修改 RuleLibrary 加载 pro-rules 目录**

```swift
// RuleLibrary.reload() 中添加：
let proRulesDir = Bundle.main.resourceURL?.appendingPathComponent("pro-rules")
if let dir = proRulesDir, FileManager.default.fileExists(atPath: dir.path) {
    let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    for file in files ?? [] where file.pathExtension == "json" {
        if let rules = loadKnobs(from: file) {
            loaded.append(contentsOf: rules)
        }
    }
}
```

- [ ] **步骤 5：端到端测试每个 App 的旋钮控制手感**
- [ ] **步骤 6：Commit**

```bash
git commit -m "feat: add Pro App knob packs for DaVinci Resolve, FCP, and Logic Pro"
```

---

## 任务 5：引导体验英文适配

**文件：**
- 修改：`PhantomKnob/View/UserGuideView.swift`
- 修改：`PhantomKnob/ViewModel/UserGuideViewModel.swift`

- [ ] **步骤 1：重写英文引导文案**

Step 1: "Step 1: Device Detection & Basic Rotation" → 简洁、动词驱动
Step 2: "Step 2: Knob Modes & Customization"
Step 3: "Step 3: Go Global"

- [ ] **步骤 2：添加手势动画说明（替代纯文字）**

考虑使用 Lottie 动画或 SwiftUI 自绘动画展示两指旋转手势。

- [ ] **步骤 3：Step 3 中 App 适配列表动态化**

根据 RuleLibrary 中实际存在的 bundled rules 动态生成列表。

- [ ] **步骤 4：Commit**

```bash
git commit -m "feat: adapt user guide for English-first onboarding experience"
```

---

## 任务 6：版本管理策略

**文件：**
- 创建：`CHANGELOG.md`
- 修改：`PhantomKnob/project.yml`
- 修改：`scripts/build_notarize.sh`

- [ ] **步骤 1：创建 CHANGELOG.md**

```markdown
# Changelog

All notable changes to PhantomKnob will be documented in this file.

## [1.0.0] - 2026-XX-XX

### Added
- Global knob control mode with trackpad two-finger rotation gesture
- Support for AXSlider, AXProgressIndicator, AXScrollBar elements
- Multiple knob modes: Fixed, Double-Ring, Variable Speed
- Custom rules system (My Knobs)
- Pro App knob packs for DaVinci Resolve, Final Cut Pro, Logic Pro
- 14-day full-feature trial
- English and Chinese (Simplified) localization
- Status bar menu with state indicator
- Settings window with hotkey customization
- Three-step interactive user guide
- Launch at login support
```

- [ ] **步骤 2：设置 build number 自增**

在 `build_notarize.sh` 中添加：
```bash
BUILD_NUMBER=$(git rev-list --count HEAD)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PROJECT_DIR/Info.plist"
```

- [ ] **步骤 3：Commit**

```bash
git commit -m "docs: add CHANGELOG and set up build number auto-increment"
```

---

## 验证计划

### 自动化测试
```bash
xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnobTests
```

### 手动验证
1. **Sentry**：制造一个测试崩溃，确认在 Sentry 面板中收到事件
2. **日志**：Release build 运行 30 分钟，确认无 debug.log 生成，Console.app 中日志分级正确
3. **状态栏图标**：在亮/暗模式下查看 4 种状态图标的显示效果
4. **Pro 旋钮包**：在 DaVinci Resolve 中实际调色验证手感
5. **引导**：以全新用户身份走完英文三步引导
