// PhantomKnob/Model/DetectedTarget.swift
import Foundation
import ApplicationServices

/// 手势开始时在光标下检测到的 UI 元素的纯元数据。无执行逻辑。
struct DetectedTarget {
    let bundleID: String        // 前台 App 的 Bundle ID，如 "com.apple.QuickTimePlayerX"
    let axRole: String          // AX 角色字符串，如 "AXSlider"
    let identifier: String?     // AXIdentifier（开发者设置，可为 nil）
    let displayName: String     // 来自 AXTitle 或 AXDescription，用于 overlay 显示
    let element: AXUIElement?   // AX 元素引用；无 AX 元素时为 nil（如 Canvas 区域）
    let parentChain: [ParentNodeInfo] // 新增：从叶子控件向上延伸的完整层级树链条

    /// 用于配置查找和状态机 identity 比较。
    var knobKey: KnobKey {
        KnobKey(bundleID: bundleID, axRole: axRole, identifier: identifier, displayName: displayName, parentChain: parentChain)
    }
}
