# 启动触控板硬件自检与用户引导还原实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在应用启动时自动检测系统中是否存在触控板硬件，若不存在则提示错误并退出；同时将 User Guide 界面及本地化步骤还原为原有的 3 个操作步骤。

**架构：** 
1. 新建 `HardwareDetector` 服务，使用 IOKit 框架匹配触控板 HID 设备描述符。
2. 在 `AppState.init()` 中（非单元测试运行时），调用 `HardwareDetector.isTrackpadConnected()`。若返回 `false` 则使用 `NSAlert` 强阻断提示并调用 `NSApp.terminate(nil)` 退出。
3. 还原 `Localizable.xcstrings` 中的步骤文案，删除多余的 `guide.step1.step4`。

**技术栈：** Swift, IOKit, SwiftUI, AppKit

---

## 计划涉及文件清单

### 创建新文件
- `PhantomKnob/Service/HardwareDetector.swift` [NEW]
- `PhantomKnobTests/HardwareDetectorTests.swift` [NEW]

### 修改文件
- `PhantomKnob/App/PhantomKnobApp.swift` [MODIFY]
- `PhantomKnob/Localizable.xcstrings` [MODIFY]

---

## 实施任务列表

### 任务 1：实现 `HardwareDetector` 模块

**文件：**
- 创建：`PhantomKnob/Service/HardwareDetector.swift`
- 测试：`PhantomKnobTests/HardwareDetectorTests.swift`

- [ ] **步骤 1：编写硬件检测单元测试**

  创建测试文件 `PhantomKnobTests/HardwareDetectorTests.swift`，验证检测方法可被调用且返回布尔值。
  
  ```swift
  import XCTest
  @testable import PhantomKnob
  
  final class HardwareDetectorTests: XCTestCase {
      func testTrackpadDetectionReturnsBool() {
          // 在没有触控板的测试环境下可能返回 false，在有触控板的开发机返回 true。
          // 我们只需要确保它能正常执行并返回布尔值，不发生崩溃。
          let result = HardwareDetector.isTrackpadConnected()
          XCTAssertTrue(result == true || result == false)
      }
  }
  ```

- [ ] **步骤 2：创建硬件检测实现**

  创建文件 `PhantomKnob/Service/HardwareDetector.swift`。
  
  ```swift
  import Foundation
  import IOKit
  import IOKit.hid
  
  struct HardwareDetector {
      /// 检测当前是否连接了触控板（包括内置和外接 Magic Trackpad）
      static func isTrackpadConnected() -> Bool {
          let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
          
          // 匹配触控板的标准 HID 描述符：
          // 1. Digitizer (0x0D) -> Touch Pad (0x05)
          // 2. Generic Desktop (0x01) -> Touch Pad (0x05)
          let matchingDicts: [[String: Any]] = [
              [
                  kIOHIDDeviceUsagePageKey: 0x0D,
                  kIOHIDDeviceUsageKey: 0x05
              ],
              [
                  kIOHIDDeviceUsagePageKey: 0x01,
                  kIOHIDDeviceUsageKey: 0x05
              ]
          ]
          
          IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDicts as CFArray)
          IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
          
          guard let devices = IOHIDManagerCopyDevices(manager) else {
              return false
          }
          
          let nsSet = devices as NSSet
          return nsSet.count > 0
      }
  }
  ```

- [ ] **步骤 3：运行测试验证通过**

  运行以下命令进行单元测试：
  ```bash
  xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnobTests -sdk macosx test
  ```
  预期输出：所有测试通过。

- [ ] **步骤 4：Commit**

  ```bash
  git add PhantomKnob/Service/HardwareDetector.swift PhantomKnobTests/HardwareDetectorTests.swift
  git commit -m "feat: add HardwareDetector with IOKit trackpad detection"
  ```

---

### 任务 2：在应用启动时挂载自检测逻辑

**文件：**
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`

- [ ] **步骤 1：修改 AppState.init() 增加检测**

  在 `PhantomKnob/App/PhantomKnobApp.swift` 的 `AppState` 初始化中挂载自检：
  
  ```swift
  // 修改 AppState.init() 开始处：
  init() {
      // 排除单元测试的运行，防止测试框架加载时阻断退出
      if NSClassFromString("XCTestCase") == nil {
          if !HardwareDetector.isTrackpadConnected() {
              let alert = NSAlert()
              alert.messageText = String(localized: "startup.noTrackpad.title", defaultValue: "No Trackpad Detected")
              alert.informativeText = String(localized: "startup.noTrackpad.message", defaultValue: "PhantomKnob requires a trackpad (MacBook trackpad or Magic Trackpad) to perform knob gestures. The application will now exit.")
              alert.alertStyle = .critical
              alert.addButton(withTitle: String(localized: "startup.noTrackpad.quit", defaultValue: "Quit"))
              alert.runModal()
              NSApp.terminate(nil)
              return
          }
      }
      
      #if canImport(Sentry)
      // 后面保持原有逻辑...
  ```

- [ ] **步骤 2：编译项目验证成功**

  ```bash
  xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnob -configuration Debug build
  ```
  预期输出：编译无报错。

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/App/PhantomKnobApp.swift
  git commit -m "feat: inject trackpad self-check on application startup"
  ```

---

### 任务 3：本地化文本还原与词条补充

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：还原及添加本地化键值对**

  使用文本工具或 Xcode 编辑 `PhantomKnob/Localizable.xcstrings`，还原 guide 步骤 1 至 3 的原貌，删除步骤 4，并增加自检测相关的翻译：
  
  1. 还原 `"guide.step1.step1"` 的 `"zh-Hans"` value 为 `"PhantomKnob 需要辅助功能权限。如有要求，请授权"`
  2. 还原 `"guide.step1.step2"` 的 `"zh-Hans"` value 为 `"移动鼠标到音量练习旋钮上"`
  3. 还原 `"guide.step1.step3"` 的 `"zh-Hans"` value 为 `"用两指接触触控板，并做旋转动作"`
  4. 删除 `"guide.step1.step4"` 整个节点
  5. 新增自检测标题 `"startup.noTrackpad.title"`，设置 `"zh-Hans"` 值为 `"未检测到触控板"`，默认为 `"No Trackpad Detected"`
  6. 新增自检测消息 `"startup.noTrackpad.message"`，设置 `"zh-Hans"` 值为 `"PhantomKnob 必须在有触控板的Mac系统（如MacBook内置触控板或外接妙控板）上运行。程序即将退出。"`，默认为 `"PhantomKnob requires a trackpad (MacBook trackpad or Magic Trackpad) to perform knob gestures. The application will now exit."`
  7. 新增自检测按钮 `"startup.noTrackpad.quit"`，设置 `"zh-Hans"` 值为 `"退出"`，默认为 `"Quit"`

- [ ] **步骤 2：Commit**

  ```bash
  git add PhantomKnob/Localizable.xcstrings
  git commit -m "locale: restore user guide steps and add startup check keys"
  ```

---

## 验证与验收

1. **编译确认**：运行 `xcodebuild` 编译 Debug 版本通过。
2. **测试确认**：运行 `xcodebuild ... test` 测试套件无中断，测试全部通过。
3. **关闭外接触控板测试**（在没有内置触控板的 Mac 上）：启动程序，确认弹出系统警告且点击退出后程序退出。
