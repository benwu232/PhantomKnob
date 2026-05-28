// PhantomKnobDetector/Service/TargetDetector.swift
import Foundation
import AppKit
import ApplicationServices

class TargetDetector {
    static let maxParentDepth = 10

    init() {}

    /// 检测鼠标位置下的可控制元素，返回 DetectedTarget。
    /// 无 AX 元素时返回 nil（调用方负责创建 fallback）。
    func detectTargetAtMousePosition() -> DetectedTarget? {
        guard AXIsProcessTrusted() else { return nil }

        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        let flippedY = screenHeight - mouseLocation.y

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &element) == .success,
              let axElement = element else { return nil }

        return findAdjustableTarget(from: axElement, depth: 0)
    }

    /// 根据 AX 属性自动探测最适合的 InputTranslation。
    /// 探测顺序：AXValue settable → axWrite；AXIncrement 存在 → arrowKeyUpDown；其他 → scrollWheelVertical
    static func autoDetectTranslation(for element: AXUIElement) -> InputTranslation {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        if settable.boolValue { return .axWrite }

        var actions: CFArray?
        AXUIElementCopyActionNames(element, &actions)
        if let actionList = actions as? [String],
           actionList.contains(kAXIncrementAction) || actionList.contains(kAXDecrementAction) {
            return .arrowKeyUpDown
        }

        return .scrollWheelVertical
    }

    func clearCache() {
        // 缓存已被移除，此为兼容性空方法
    }

    // MARK: - Private

    private func findAdjustableTarget(from element: AXUIElement, depth: Int) -> DetectedTarget? {
        if let target = tryBuildTarget(from: element) { return target }
        guard depth < Self.maxParentDepth else { return nil }

        var parent: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent) == .success,
              let parentRef = parent else { return nil }
        let parentElement = unsafeBitCast(parentRef, to: AXUIElement.self)
        return findAdjustableTarget(from: parentElement, depth: depth + 1)
    }

    private func tryBuildTarget(from element: AXUIElement) -> DetectedTarget? {
        // 元素必须有 AXMinValue + AXMaxValue 才视为可调节
        guard Self.getDouble(from: element, attribute: kAXMinValueAttribute) != nil,
              Self.getDouble(from: element, attribute: kAXMaxValueAttribute) != nil else { return nil }

        let role        = Self.getString(from: element, attribute: kAXRoleAttribute) ?? "AXUnknown"
        let identifier  = Self.getString(from: element, attribute: kAXIdentifierAttribute)
        let displayName = Self.getString(from: element, attribute: kAXTitleAttribute)
                       ?? Self.getString(from: element, attribute: kAXDescriptionAttribute)
                       ?? role
        let bundleID    = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""

        return DetectedTarget(
            bundleID: bundleID,
            axRole: role,
            identifier: identifier,
            displayName: displayName,
            element: element
        )
    }

    // MARK: - AX attribute helpers

    static func getDouble(from element: AXUIElement, attribute: String) -> Double? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let number = value as? NSNumber else { return nil }
        return number.doubleValue
    }

    static func getString(from element: AXUIElement, attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let string = value as? String else { return nil }
        return string
    }
}
