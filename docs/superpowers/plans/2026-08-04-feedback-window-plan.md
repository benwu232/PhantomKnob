# Feedback Window & Multi-Channel Feedback Support Implementation Plan

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 PhantomKnob 中构建原生的 SwiftUI Feedback 窗口（`FeedbackView` + `FeedbackWindowController`），支持 GitHub Issues 接入、Email 唤起、客服邮箱复制与应用诊断信息一键复制功能，替代现有的简易 `mailto:` 菜单动作。

**架构：** 使用 `FeedbackWindowController` (单例 `NSWindowController`) 管理包含 `FeedbackView` 的原生浮动/普通窗口。`FeedbackView` 展现多通道反馈按钮（GitHub Issues、Email 发送与复制）及只读的格式化诊断文本框，并与 `StatusBarController` 的 `Send Feedback…` 菜单项无缝对接。

**技术栈：** Swift 5.9, SwiftUI, AppKit (`NSWindow`, `NSPasteboard`, `NSWorkspace`), XCTest.

---

## 文件结构

### 1. 新建文件
- `PhantomKnob/Service/FeedbackWindowController.swift`: 负责反馈窗口单例管理、显示/隐藏、激活策略与外观配置。
- `PhantomKnob/View/FeedbackView.swift`: 反馈界面的 SwiftUI 视图，包含 GitHub 卡片、Email 卡片、诊断信息展示与剪贴板复制逻辑。
- `PhantomKnob/ViewModel/FeedbackViewModel.swift`: 处理诊断信息构建、`mailto:` URL 生成以及剪贴板操作，方便独立单元测试。
- `PhantomKnobTests/FeedbackViewModelTests.swift`: 测试诊断文本格式化、Mailto URL 编码及剪贴板逻辑的单元测试。
- `PhantomKnobTests/FeedbackWindowControllerTests.swift`: 测试窗口生命周期（显示、聚焦、隐藏）的单元测试。

### 2. 修改文件
- `PhantomKnob/Service/StatusBarController.swift`: 将现有的直接发送邮件 `sendFeedback()` Selector 修改为唤起 `FeedbackWindowController.shared.show()`。
- `PhantomKnob/Localizable.xcstrings`: 补充反馈窗口相关的多语言本地化条目（英文、中文等）。
- `PhantomKnobTests/StatusBarControllerTests.swift`: 更新状态栏菜单单元测试中对于 `sendFeedback` 的行为断言。

---

## 任务拆解与实现步骤

### 任务 1：创建 `FeedbackViewModel` 及逻辑层单元测试

**文件：**
- 创建：`PhantomKnob/ViewModel/FeedbackViewModel.swift`
- 创建：`PhantomKnobTests/FeedbackViewModelTests.swift`

- [ ] **步骤 1：编写失败的单元测试**

```swift
// PhantomKnobTests/FeedbackViewModelTests.swift
import XCTest
@testable import PhantomKnob

final class FeedbackViewModelTests: XCTestCase {
    func testGenerateDiagnosticInfoContainsRequiredFields() {
        let viewModel = FeedbackViewModel()
        let diagnostics = viewModel.generateDiagnosticInfo()
        
        XCTAssertTrue(diagnostics.contains("App: PhantomKnob"))
        XCTAssertTrue(diagnostics.contains("macOS:"))
        XCTAssertTrue(diagnostics.contains("Device:"))
        XCTAssertTrue(diagnostics.contains("License:"))
    }
    
    func testMailtoURLConstruction() {
        let viewModel = FeedbackViewModel()
        let url = viewModel.buildMailtoURL()
        
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.starts(with: "mailto:phantomknob232@gmail.com") ?? false)
        XCTAssertTrue(url?.absoluteString.contains("subject=") ?? false)
    }
    
    func testGitHubURLConstruction() {
        let viewModel = FeedbackViewModel()
        let url = viewModel.gitHubIssuesURL
        
        XCTAssertEqual(url.absoluteString, "https://github.com/benwu232/PhantomKnob/issues")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/FeedbackViewModelTests`
预期：FAIL，提示 `FeedbackViewModel` 未定义。

- [ ] **步骤 3：编写 `FeedbackViewModel` 最小实现代码**

```swift
// PhantomKnob/ViewModel/FeedbackViewModel.swift
import Foundation
import AppKit

public class FeedbackViewModel: ObservableObject {
    @Published public var isCopiedEmail: Bool = false
    @Published public var isCopiedDiagnostics: Bool = false
    
    public let supportEmail = "phantomknob232@gmail.com"
    public let gitHubIssuesURL = URL(string: "https://github.com/benwu232/PhantomKnob/issues")!
    
    public init() {}
    
    public func generateDiagnosticInfo() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let model = Host.current().localizedName ?? "Unknown Mac"
        let license = "\(LicenseManager.shared.currentState)"
        
        return """
        App: PhantomKnob v\(version) (\(build))
        macOS: \(os)
        Device: \(model)
        License: \(license)
        """
    }
    
    public func buildMailtoURL() -> URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let diagnostics = generateDiagnosticInfo()
        
        let subject = "PhantomKnob Feedback (v\(version) build \(build))"
        let body = "\n\n---\n\(diagnostics)"
        
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        return URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
    
    public func copySupportEmail() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(supportEmail, forType: .string)
        isCopiedEmail = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isCopiedEmail = false
        }
    }
    
    public func copyDiagnostics() {
        let info = generateDiagnosticInfo()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
        isCopiedDiagnostics = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isCopiedDiagnostics = false
        }
    }
    
    public func openGitHubIssues() {
        NSWorkspace.shared.open(gitHubIssuesURL)
    }
    
    public func openEmailClient() {
        if let url = buildMailtoURL() {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/FeedbackViewModelTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/ViewModel/FeedbackViewModel.swift PhantomKnobTests/FeedbackViewModelTests.swift
git commit -m "feat: add FeedbackViewModel and unit tests"
```

---

### 任务 2：实现 SwiftUI `FeedbackView` 界面

**文件：**
- 创建：`PhantomKnob/View/FeedbackView.swift`

- [ ] **步骤 1：创建 `FeedbackView.swift` 视图组件**

```swift
// PhantomKnob/View/FeedbackView.swift
import SwiftUI

public struct FeedbackView: View {
    @StateObject private var viewModel = FeedbackViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Section
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "feedback.title", defaultValue: "Send Feedback"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text(String(localized: "feedback.subtitle", defaultValue: "We'd love to hear your thoughts, feature requests, or issue reports."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Channels Grid / Cards
            VStack(spacing: 12) {
                // GitHub Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "number.square.fill")
                                .foregroundColor(.accentColor)
                            Text(String(localized: "feedback.github.title", defaultValue: "GitHub Issues"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(String(localized: "feedback.github.description", defaultValue: "Report bugs, request features, or view existing discussions."))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        viewModel.openGitHubIssues()
                    }) {
                        Text(String(localized: "feedback.github.button", defaultValue: "Open GitHub"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Email Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text(String(localized: "feedback.email.title", defaultValue: "Email Support"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(viewModel.supportEmail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.copySupportEmail()
                        }) {
                            Text(viewModel.isCopiedEmail ? 
                                 String(localized: "feedback.copied", defaultValue: "Copied!") : 
                                 String(localized: "feedback.email.copy", defaultValue: "Copy"))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            viewModel.openEmailClient()
                        }) {
                            Text(String(localized: "feedback.email.button", defaultValue: "Send Email"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
            }
            
            // Diagnostics Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "feedback.diagnostics.title", defaultValue: "System Diagnostics"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        viewModel.copyDiagnostics()
                    }) {
                        Label(viewModel.isCopiedDiagnostics ? 
                              String(localized: "feedback.copied", defaultValue: "Copied!") : 
                              String(localized: "feedback.diagnostics.copy", defaultValue: "Copy Info"),
                              systemImage: viewModel.isCopiedDiagnostics ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                
                Text(viewModel.generateDiagnosticInfo())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                    .cornerRadius(6)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 480, height: 380)
    }
}
```

- [ ] **步骤 2：Commit**

```bash
git add PhantomKnob/View/FeedbackView.swift
git commit -m "feat: add FeedbackView SwiftUI component"
```

---

### 任务 3：实现 `FeedbackWindowController` 及单元测试

**文件：**
- 创建：`PhantomKnob/Service/FeedbackWindowController.swift`
- 创建：`PhantomKnobTests/FeedbackWindowControllerTests.swift`

- [ ] **步骤 1：编写失败的窗口控制器测试**

```swift
// PhantomKnobTests/FeedbackWindowControllerTests.swift
import XCTest
@testable import PhantomKnob

final class FeedbackWindowControllerTests: XCTestCase {
    func testFeedbackWindowControllerShowAndHide() {
        let controller = FeedbackWindowController.shared
        XCTAssertFalse(controller.isVisible)
        
        controller.show()
        XCTAssertTrue(controller.isVisible)
        
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/FeedbackWindowControllerTests`
预期：FAIL，提示 `FeedbackWindowController` 未定义。

- [ ] **步骤 3：实现 `FeedbackWindowController`**

```swift
// PhantomKnob/Service/FeedbackWindowController.swift
import AppKit
import SwiftUI
import os

class FeedbackWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class FeedbackWindowController: NSObject, NSWindowDelegate {
    static let shared = FeedbackWindowController()
    
    private var window: FeedbackWindow?
    
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func createWindow() {
        let width: CGFloat = 480
        let height: CGFloat = 380
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
        
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        let win = FeedbackWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .normal
        win.delegate = self
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.masksToBounds = true
        
        win.contentView = visualEffectView
        
        let hostingView = NSHostingView(rootView: FeedbackView())
        hostingView.frame = visualEffectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(hostingView)
        
        self.window = win
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        hide()
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/FeedbackWindowControllerTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Service/FeedbackWindowController.swift PhantomKnobTests/FeedbackWindowControllerTests.swift
git commit -m "feat: implement FeedbackWindowController and lifecycle tests"
```

---

### 任务 4：连接 Status Bar 菜单项与更新 `StatusBarController`

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift:444-470`
- 修改：`PhantomKnobTests/StatusBarControllerTests.swift`

- [ ] **步骤 1：更新 `StatusBarController.swift` 中的 `sendFeedback()` 逻辑**

修改 `StatusBarController.swift` 中的 `sendFeedback()` 方法：

```swift
    @objc private func sendFeedback() {
        FeedbackWindowController.shared.show()
        AnalyticsManager.shared.trackEvent("feedbackClicked")
    }
```

- [ ] **步骤 2：运行单元测试进行回归测试**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS'`
预期：ALL PASS

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Service/StatusBarController.swift
git commit -m "refactor: update StatusBarController to trigger FeedbackWindowController"
```

---

### 任务 5：多语言本地化文案补充 (`Localizable.xcstrings`)

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：在 `Localizable.xcstrings` 中增加 Feedback 相关的键值项**

在 `Localizable.xcstrings` 中包含以下 key 及其英文/中文翻译：
- `feedback.title`: "Send Feedback" / "发送反馈"
- `feedback.subtitle`: "We'd love to hear your thoughts, feature requests, or issue reports." / "欢迎提交意见反馈、功能建议或 Bug 汇报。"
- `feedback.github.title`: "GitHub Issues" / "GitHub Issues"
- `feedback.github.description`: "Report bugs, request features, or view existing discussions." / "提交 Bug 报告、建议新功能或查看已有讨论。"
- `feedback.github.button`: "Open GitHub" / "前往 GitHub"
- `feedback.email.title`: "Email Support" / "邮件支持"
- `feedback.email.button`: "Send Email" / "发送邮件"
- `feedback.email.copy`: "Copy" / "复制"
- `feedback.diagnostics.title`: "System Diagnostics" / "系统与应用诊断信息"
- `feedback.diagnostics.copy`: "Copy Info" / "复制诊断信息"
- `feedback.copied`: "Copied!" / "已复制！"

- [ ] **步骤 2：运行全量单元测试验证构建与本地化正常**

运行：`xcodebuild test -scheme PhantomKnob -destination 'platform=macOS'`
预期：ALL PASS

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Localizable.xcstrings
git commit -m "loc: add localizations for Feedback window UI"
```

---

## 自检 Checklist

1. **规格覆盖度：** 涵盖 GitHub Issues、Email 唤起、Email 地址复制、系统诊断信息展示与复制，以及 StatusBar 菜单连接与多语言支持。
2. **占位符扫描：** 无 `TODO`、`待定` 或未完成代码块。所有文件路径均精确指定。
3. **类型一致性：** `FeedbackViewModel` 的公开方法与 `FeedbackView` 中的调用全一致。
4. **编译与验证：** 包含每个任务对应的精确单元测试验证命令与输出预期。

---

## 执行交接

实现计划已完成并保存至 `docs/superpowers/plans/2026-08-04-feedback-window-plan.md`。

请选择下一步的执行方式：

1. **子代理驱动（推荐）** - 使用 `subagent-driven-development` 技能，每个任务调度一个子代理独立执行，并在任务间进行审查。
2. **内联执行** - 在当前会话中使用 `executing-plans` 技能，批量执行任务并在检查点暂停审查。

请问你希望采用哪种方式开始执行？
