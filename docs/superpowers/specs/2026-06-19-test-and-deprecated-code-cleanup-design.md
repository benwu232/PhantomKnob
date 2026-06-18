# 单元测试修复、废弃代码清理与文档对齐设计方案

本文档详述了 Phantom Knob 中修复 `testOptionHoldTemporaryToggle` 单元测试错误、清理已废弃的旧版 `ControlTarget` 体系，以及对齐 `CONTEXT.md` 快捷键描述的设计方案。

---

## 1. 业务目标与需求 (Goals & Requirements)

* **单元测试状态健康**：在任何无系统辅助功能 (Accessibility) 权限的环境下（包括 Xcode 命令行 `xcodebuild`），单元测试均能够 100% 通过。
* **codebase 精简与健康**：清理不再使用的早期协议及其实现文件，降低认知负载，优化工程架构。
* **文档与代码状态对齐**：确保代表当前系统现状的核心文档 ([CONTEXT.md](file:///Users/wb/work/phantom_knob_mac/CONTEXT.md)) 中的激活热键与代码中实际运行的热键保持完全一致。

---

## 2. 详细设计 (Detailed Design)

### 2.1 修复 `testOptionHoldTemporaryToggle` 单元测试
在 [CustomKnobTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/CustomKnobTests.swift) 中，通过为 `KnobStateManager` 注入 Mock block 的方式，强制其在测试环境中认为辅助功能已经授权：

```swift
manager.isProcessTrusted = { true }
```

### 2.2 废弃代码清理
以下文件已彻底废弃且无其他代码调用，需要进行物理删除：
* `PhantomKnob/Control/ControlTarget.swift` (已废弃协议定义)
* `PhantomKnob/Control/GenericControlTarget.swift` (已废弃协议实现)
* `PhantomKnob/Service/AccessibilityTarget.swift` (已废弃协议实现)
* `PhantomKnob/PhantomKnobTests/AccessibilityTargetTests.swift` (已废弃实现之测试)

对遗留的 `DemoSliderTarget` 和 `DemoViewModel` 调整为具体类直接引用的依赖方式，不再继承/实现任何旧版协议。

### 2.3 快捷键文档对齐
在 [CONTEXT.md](file:///Users/wb/work/phantom_knob_mac/CONTEXT.md) 中，将默认激活热键由历史废弃的 `⌘⇧K` 统一对齐为代码及设置页中实际实现的 `⌘⌥R` (Command + Option + R)。

---

## 3. 验证计划 (Verification Plan)

### 3.1 自动化测试 (Automated Tests)
重新运行工程生成工具，并执行全部单元测试以确保没有引起任何编译错误或测试失败：
```bash
cd PhantomKnob && xcodegen generate
cd ..
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```
**预期结果**：
* 编译通过。
* 所有单元测试全部顺利 Passed。

### 3.2 手动验证 (Manual Verification)
* 检查 `CONTEXT.md` 修改，确认全局热键描述准确无误。
