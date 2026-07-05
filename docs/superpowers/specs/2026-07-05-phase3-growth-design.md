# 2026-07-05 Phase 3 Growth Design Spec

本文档详述了 Phantom Knob macOS 客户端及落地页 Phase 3 增长功能的详细设计与架构规范。

## 1. 目标与范围
添加提升用户留存和口碑的增长功能，包括：
1. **自动更新**：集成 Sparkle 自动更新，使用原生 AppKit UI 引导安全升级。
2. **使用分析**：集成 TelemetryDeck 追踪关键交互与留存指标，支持 Opt-out 隐私开关。
3. **应用内反馈**：通过 Status Bar 菜单一键拉起本地邮件系统，并自动带入设备环境参数。
4. **营销素材与落地页**：在落地页 `index.html` 引入高级 Showcase 区域，配合 `generate_image` 生成插画素材，并为视频和截图预留高级样式。
5. **Release Notes UI**：开发自定义 SwiftUI 深色毛玻璃窗口，在更新后提示新特性，且支持不再提示的本地记忆。

---

## 2. 详细设计与接口设计

### 2.1 任务 1：Sparkle 自动更新
* **依赖引入**：通过 XcodeGen 依赖注入 Sparkle SPM 包。
* **UpdateManager** (`UpdateManager.swift`)：
  - 初始化：通过 `SPUStandardUpdaterController` 启动 Sparkle 自动校验。
  - 核心接口：
    ```swift
    final class UpdateManager: ObservableObject {
        static let shared = UpdateManager()
        func checkForUpdates()
        var canCheckForUpdates: Bool { get }
    }
    ```
* **EdDSA 密钥生成与 Info.plist 配置**：
  - 调用 `./.build/artifacts/Sparkle/bin/generate_keys` 生成 EdDSA 密钥对。公钥写入 `project.yml` 下的 `SUPublicEDKey`。
  - 配置 `SUFeedURL` 为 `https://phantomknob.com/appcast.xml`。

### 2.2 任务 2：使用分析（TelemetryDeck）
* **依赖引入**：引入 `TelemetryClient` SPM。
* **AnalyticsManager** (`AnalyticsManager.swift`)：
  - 提供单例封装，监控 `UserDefaults` 中的 `disableAnalytics` 开关。
  - 提供 `trackEvent(_:parameters:)` 主动记录功能启动、旋钮激活、试用到付费转化等节点。
* **隐私退出（Opt-out Controls）**：
  - 在 `SettingsView.swift` 中提供 "Share usage statistics with developer" 的 Toggle。

### 2.3 任务 3：应用内反馈
* **StatusBarController 菜单扩展**：
  - 菜单栏末尾前追加 "Send Feedback..."。
  - 点击时运行 `sendFeedback()`。它利用 `NSWorkspace.shared.open()` 打开一个带有自动填充的 `mailto` Link：
    `mailto:support@phantomknob.com?subject=PhantomKnob%20Feedback%20(v1.0%20build%201)&body=...`
  - 自动填充内容包括：App 版本与 Build 号、macOS 版本、硬件 Mac 设备型号、激活授权状态。

### 2.4 任务 4：营销素材与落地页更新
* **Showcase 布局设计**：
  - 在 `website/index.html` 新增 `#showcase` 栅格区域，包含毛玻璃背景的 Video Showcase 容器。
  - 截图容器展示三张 16:10 主角卡片，包含 hover 放大的拟态微动特效。
* **占位图生成**：
  - 使用 `generate_image` 生成三张高保真产品界面插图，填入 `website/assets` 占位：
    - `screenshot_overlay.png`
    - `screenshot_hud.png`
    - `screenshot_settings.png`

### 2.5 任务 5：Release Notes UI
* **数据存储**：
  - 声明 `PhantomKnob/Resources/release-notes.json` 文件，支持按版本作为 Key 存放结构化更新文本。
* **ReleaseNotesView** (`ReleaseNotesView.swift`)：
  - SwiftUI 组件，支持渲染 title、多行 item、不再提示 checkbox 及 "Got it" 关闭按钮。
* **ReleaseNotesController** (`ReleaseNotesController.swift`)：
  - 实例化无边框 `NSWindow` (520x380)，插入 `NSVisualEffectView` 呈现原生毛玻璃材质。
  - `showIfNeeded()`：获取当前版本对比 `UserDefaults` 里的 `lastSeenReleaseNotesVersion` / `lastSeenReleaseNotesVersion`。如果不同且新手引导已结，则解析 json 文件展示。

---

## 3. 验证方案

### 3.1 自动化测试
* 运行 `xcodebuild test` 验证 `ReleaseNotesController` 解析 json 数据结构的单元测试。

### 3.2 手动验证
1. **自动更新测试**：修改 appcast 文件的版本号为更高，确认能通过 Sparkle 原生提示拉起更新弹窗。
2. **分析统计验证**：运行 App 检查控制台输出，确认 TelemetryDeck SDK 成功完成握手和数据上传。
3. **反馈链接测试**：在菜单栏中点击 "Send Feedback..."，确保能自动拉起 Mail.app 且收件人、标题和机器调试配置完全自动填好。
4. **日志弹窗测试**：模拟更新，确认启动后立即弹出 What's New 日志框，选中不再提示后，下一次冷启动不再展示。
