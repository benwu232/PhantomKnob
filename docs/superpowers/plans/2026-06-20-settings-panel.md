# 设置面板 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 重构 SettingsView，实现热键自定义、权限状态显示、启动引导开关、触控板重新检测四个设置项，并正确接入菜单「设置...」入口。

**架构：**
- `SettingsView.swift` 全量重写：两个 Tab（通用/关于），通用 Tab 用独立 Section 卡片组织
- `HotkeyRecorderView.swift` 新建：热键录制浮动窗口
- `HotkeySettings.swift` 新建：热键读写逻辑（UserDefaults），供 SettingsView 和 StatusBarController 共享
- `StatusBarController.swift` 修改：热键从 UserDefaults 动态读取，`openSettings()` 接入系统 API

**技术栈：** SwiftUI、AppKit、UserDefaults、NSEvent (keyDown monitor)、macOS Settings Scene

**规格参考：** `docs/superpowers/specs/2026-06-20-settings-panel-design.md`

---

## 任务 1：热键存储层（HotkeySettings）

**文件：**
- 创建：`PhantomKnob/Model/HotkeySettings.swift`

热键需要在 `StatusBarController`（运行时监听）和 `SettingsView`（UI 显示/修改）之间共享。创建一个轻量共享层，封装 UserDefaults 读写，提供变更通知。

- [ ] **步骤 1：创建 `HotkeySettings.swift`**

```swift
import AppKit
import Combine

/// 热键设置存储。UserDefaults 键名与 StatusBarController 的监听器对应。
/// keyCode: UInt16 — NSEvent.keyCode，例如 R = 15
/// modifiers: UInt — NSEvent.ModifierFlags.rawValue，例如 .command | .option
class HotkeySettings: ObservableObject {
    static let shared = HotkeySettings()

    private static let keyCodeKey = "globalHotkeyKeyCode"
    private static let modifiersKey = "globalHotkeyModifiers"

    // 默认值：⌘⌥R（keyCode=15，command|option）
    static let defaultKeyCode: UInt16 = 15
    static let defaultModifiers: NSEvent.ModifierFlags = [.command, .option]

    @Published var keyCode: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(keyCode), forKey: Self.keyCodeKey)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }

    @Published var modifiers: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(modifiers.rawValue, forKey: Self.modifiersKey)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }

    private init() {
        let savedKeyCode = UserDefaults.standard.integer(forKey: Self.keyCodeKey)
        let savedModifiers = UserDefaults.standard.integer(forKey: Self.modifiersKey)
        if savedKeyCode != 0 {
            keyCode = UInt16(savedKeyCode)
            modifiers = NSEvent.ModifierFlags(rawValue: UInt(savedModifiers))
        } else {
            keyCode = Self.defaultKeyCode
            modifiers = Self.defaultModifiers
        }
    }

    /// 将热键格式化为可读字符串，例如 "⌘⌥R"
    var displayString: String {
        var parts = ""
        if modifiers.contains(.control) { parts += "⌃" }
        if modifiers.contains(.option)  { parts += "⌥" }
        if modifiers.contains(.shift)   { parts += "⇧" }
        if modifiers.contains(.command) { parts += "⌘" }
        if let char = keyCodeToChar(keyCode) {
            parts += char.uppercased()
        } else {
            parts += "[\(keyCode)]"
        }
        return parts
    }

    private func keyCodeToChar(_ code: UInt16) -> String? {
        let map: [UInt16: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
            11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",31:"O",32:"U",
            34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",
            18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",25:"9",26:"7",28:"8",29:"0"
        ]
        return map[code]
    }
}

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("com.phantomknob.hotkeyDidChange")
}
```

- [ ] **步骤 2：Commit**

```bash
git add PhantomKnob/Model/HotkeySettings.swift
git commit -m "feat: add HotkeySettings shared storage layer"
```

---

## 任务 2：StatusBarController 接入动态热键

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`

当前两处热键监听硬编码 `keyCode == 15 && [.command, .option]`，需改为从 `HotkeySettings.shared` 动态读取，并监听 `hotkeyDidChange` 通知以重新注册监听器。`openSettings()` 改用标准 API。

- [ ] **步骤 1：添加 Combine 导入和变更监听**

在 `StatusBarController` 顶部添加：

```swift
import Combine
```

在类属性区添加：

```swift
private var hotkeyChangeObserver: AnyCancellable?
```

在 `init()` 末尾（`setupGlobalHotkey()` 和 `setupLocalHotkey()` 调用之后）追加：

```swift
// 热键变更时重新注册监听器
hotkeyChangeObserver = NotificationCenter.default
    .publisher(for: .hotkeyDidChange)
    .sink { [weak self] _ in self?.reinstallHotkeyMonitors() }
```

新增方法：

```swift
private func reinstallHotkeyMonitors() {
    if let m = globalHotkeyMonitor { NSEvent.removeMonitor(m); globalHotkeyMonitor = nil }
    if let m = localHotkeyMonitor  { NSEvent.removeMonitor(m); localHotkeyMonitor = nil }
    setupGlobalHotkey()
    setupLocalHotkey()
}
```

- [ ] **步骤 2：替换两处硬编码热键判断**

在 `setupLocalHotkey` 和 `setupGlobalHotkey` 的 keyDown 回调中，将原有：

```swift
if event.keyCode == 15 {
    let hasCmdOpt = event.modifierFlags.contains([.command, .option])
    let hasCtrlOpt = event.modifierFlags.contains([.control, .option])
    if hasCmdOpt || hasCtrlOpt { ... }
}
```

替换为：

```swift
let hs = HotkeySettings.shared
let pressedMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
if event.keyCode == hs.keyCode && pressedMods == hs.modifiers {
    // ... 原有触发逻辑不变（self?.toggleMode() 等）
}
```

> 注意：同时删除 `setupLocalHotkey` 中另一处硬编码的 `keyCode == 49`（⌥Space，KnobPanel 快捷键）——该行与热键自定义无关，保持不变。

- [ ] **步骤 3：修改 `openSettings()`**

```swift
@objc private func openSettings() {
    if #available(macOS 14, *) {
        NSApp.sendAction(#selector(NSApplication.showSettingsWindow(_:)), to: nil, from: nil)
    } else {
        NSApp.sendAction(Selector("showPreferencesWindow:"), to: nil, from: nil)
    }
    NSApp.activate(ignoringOtherApps: true)
}
```

删除类属性 `var onOpenSettings: (() -> Void)?` 以及任何外部对它的赋值。

- [ ] **步骤 4：构建验证**

`Cmd+B` 确认编译通过。

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Service/StatusBarController.swift
git commit -m "feat: dynamic hotkey from HotkeySettings; open settings via system API"
```

---

## 任务 3：热键录制视图（HotkeyRecorderView）

**文件：**
- 创建：`PhantomKnob/View/HotkeyRecorderView.swift`

内嵌在设置面板行内的小组件：点击「修改...」进入录制模式，捕获 keyDown 写入 `HotkeySettings`，取消则恢复。

- [ ] **步骤 1：创建文件**

```swift
import SwiftUI
import AppKit

/// 内嵌热键录制控件。在设置面板的 LabeledContent value 区域使用。
struct HotkeyRecorderView: View {
    @ObservedObject private var settings = HotkeySettings.shared
    @State private var isRecording = false
    @State private var conflictMessage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                Text("请按下快捷键…")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 120, alignment: .leading)
                Button("取消") { stopRecording() }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
            } else {
                Text(settings.displayString)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                Button("修改…") { startRecording() }
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
            }
            if let msg = conflictMessage {
                Text(msg).font(.caption).foregroundColor(.orange)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        conflictMessage = nil
        // 用静态 var 储存 monitor（struct 无法持有引用类型属性并在闭包中 mutate）
        HotkeyRecorderView.installMonitor { [self] event in
            handleKeyDown(event)
        }
    }

    private func stopRecording() {
        isRecording = false
        HotkeyRecorderView.removeMonitor()
    }

    private func handleKeyDown(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !mods.isEmpty, event.keyCode != 0 else { return }
        // 系统保留键黑名单（Cmd+Q / Cmd+W / Cmd+H）
        let reserved: [(UInt16, NSEvent.ModifierFlags)] = [
            (12, [.command]), (13, [.command]), (4, [.command])
        ]
        if reserved.contains(where: { event.keyCode == $0.0 && mods == $0.1 }) {
            conflictMessage = "该快捷键被系统保留"
            return
        }
        HotkeySettings.shared.keyCode = event.keyCode
        HotkeySettings.shared.modifiers = mods
        conflictMessage = nil
        stopRecording()
    }

    // MARK: - Static monitor management

    private static var activeMonitor: Any?

    private static func installMonitor(handler: @escaping (NSEvent) -> Void) {
        removeMonitor()
        activeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return nil
        }
    }

    private static func removeMonitor() {
        if let m = activeMonitor { NSEvent.removeMonitor(m); activeMonitor = nil }
    }
}
```

- [ ] **步骤 2：构建验证**

`Cmd+B`。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/View/HotkeyRecorderView.swift
git commit -m "feat: HotkeyRecorderView inline hotkey capture"
```

---

## 任务 4：重写 SettingsView

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`（全量替换）

按规格实现两个 Tab：通用（热键/权限/启动/触控板）+ 关于。删除旧灵敏度代码。

- [ ] **步骤 1：全量替换 `SettingsView.swift`**

```swift
import SwiftUI
import AppKit

// MARK: - 根视图

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gear") }
            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 320)
    }
}

// MARK: - 通用 Tab

struct GeneralSettingsView: View {
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    @AppStorage("skipUserGuideOnStartup") private var skipUserGuideOnStartup = false

    var body: some View {
        Form {
            // ── 热键 ──────────────────────────────────────
            Section {
                LabeledContent {
                    HotkeyRecorderView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全局控制开关")
                        Text("激活 / 关闭旋钮控制模式")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            } header: { Text("热键") }

            // ── 辅助功能权限 ──────────────────────────────
            Section {
                HStack {
                    Image(systemName: hasAccessibilityPermission
                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .red)
                    Text(hasAccessibilityPermission ? "已授权" : "未授权")
                    Spacer()
                    if !hasAccessibilityPermission {
                        Button("打开系统设置") { openAccessibilityPreferences() }
                    }
                }
            } header: { Text("辅助功能权限") }
              footer: {
                if !hasAccessibilityPermission {
                    Text("全局控制模式必须有辅助功能权限才能工作。")
                        .foregroundColor(.secondary)
                }
            }

            // ── 启动 ──────────────────────────────────────
            Section {
                Toggle("启动时显示使用引导", isOn: Binding(
                    get: { !skipUserGuideOnStartup },
                    set: { skipUserGuideOnStartup = !$0 }
                ))
            } header: { Text("启动") }

            // ── 触控板 ────────────────────────────────────
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("重新检测触控板")
                        Text("更换硬件后使用")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("重新检测…") { resetAndRedetect() }
                }
            } header: { Text("触控板") }
        }
        .formStyle(.grouped)
        .onAppear { hasAccessibilityPermission = AXIsProcessTrusted() }
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func resetAndRedetect() {
        UserDefaults.standard.removeObject(forKey: "com.phantomknob.detectionResult")
        UserGuideWindowController.shared.show()
    }
}

// MARK: - 关于 Tab

struct AboutView: View {
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "版本 \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable().frame(width: 72, height: 72)
                    .cornerRadius(16)
            }
            VStack(spacing: 4) {
                Text("Phantom Knob").font(.title2).fontWeight(.bold)
                Text(versionString).foregroundColor(.secondary).font(.subheadline)
            }
            Text("使用两指旋转手势，像拨动旋钮一样\n精确控制任意应用中的滑块和进度条")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary).font(.callout)
            Button("使用引导") { UserGuideWindowController.shared.show() }
                .buttonStyle(.link)
            Spacer()
        }
        .frame(maxWidth: .infinity).padding()
    }
}

#Preview { SettingsView() }
```

- [ ] **步骤 2：构建 + 手动验证**

`Cmd+B` → 运行 App：
1. 菜单「设置...」弹出设置窗口
2. 通用 Tab 显示四个 Section
3. 关于 Tab 显示 App 图标和版本
4. 启动引导 Toggle 与 `UserDefaults["skipUserGuideOnStartup"]` 取反正确

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/View/SettingsView.swift
git commit -m "feat: rewrite SettingsView — hotkey, permissions, startup, trackpad, about"
```

---

## 任务 5：热键自定义端到端验证

**文件：**（验证任务，无新代码）

- [ ] **步骤 1：录制新热键**

运行 App → 设置 → 通用 → 「修改…」→ 按 `⌘⇧K`（command+shift，keyCode=40）→ 显示应更新为 `⌘⇧K`。

- [ ] **步骤 2：验证触发**

在任意其他 App 按 `⌘⇧K` → PhantomKnob 进入激活状态（图标变为 filled circle）。旧热键 `⌘⌥R` 不再触发。

- [ ] **步骤 3：验证持久化**

退出并重启 App → 设置中显示 `⌘⇧K`，且该热键仍有效。

- [ ] **步骤 4：如有 bug，修复后 commit**

```bash
git add -A && git commit -m "fix: hotkey persistence/reload"
```

---

## 任务 6：清理旧代码

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：删除 KnobStateManager 中旧灵敏度读取**

搜索并删除读取 `globalSensitivity`、`sliderSensitivity`、`progressSensitivity` 的 UserDefaults 行（约位于第 701、732、737、739、955、988、992、994 行），连同相关 `settingsSensitivity` 变量赋值一并删除。`Cmd+B` 验证编译通过。

- [ ] **步骤 2：删除 StatusBarController 的 onOpenSettings callback**

删除：
```swift
var onOpenSettings: (() -> Void)?
```
以及 `AppState` 或其他地方对该属性的赋值。`Cmd+B` 验证编译通过。

- [ ] **步骤 3：运行测试套件**

```bash
xcodebuild test \
  -project PhantomKnob/PhantomKnob.xcodeproj \
  -scheme PhantomKnob \
  -destination 'platform=macOS' \
  2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/Service/KnobStateManager.swift \
        PhantomKnob/Service/StatusBarController.swift
git commit -m "chore: remove legacy sensitivity reads and onOpenSettings callback"
```

---

## 自检

**规格覆盖度：**
- [x] 热键 Section（修改 + 录制 + 持久化）→ 任务 1、2、3、4、5
- [x] 辅助功能权限状态显示 → 任务 4
- [x] 启动引导 Toggle → 任务 4
- [x] 重新检测触控板按钮 → 任务 4
- [x] 关于 Tab → 任务 4
- [x] 菜单「设置...」入口接入 → 任务 2
- [x] 旧灵敏度代码清理 → 任务 6

**占位符扫描：** 无 TODO/待定/后续实现。

**类型一致性：**
- `HotkeySettings.shared` 任务 1 定义，任务 2/3/4 使用
- `HotkeyRecorderView` 任务 3 定义，任务 4 中 `SettingsView` 引用
- `Notification.Name.hotkeyDidChange` 任务 1 定义，任务 2 订阅
