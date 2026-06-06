// PhantomKnobDetector/Control/AXWriteTranslator.swift
import Foundation
import ApplicationServices

/// 通过 Accessibility API 直接读-改-写 AXValue。
/// 适用于：系统音量、系统亮度、标准 AXSlider 等 AXValue settable 的控件。
final class AXWriteTranslator: InputTranslator {
    private let element: AXUIElement
    private let minValue: Double
    private let maxValue: Double
    var scale: Double   // 从 ScaleConfig 解析好后传入

    init(element: AXUIElement, minValue: Double, maxValue: Double, scale: Double = 1.0) {
        self.element = element
        self.minValue = minValue
        self.maxValue = maxValue
        self.scale = scale
        _ = AXUIElementSetMessagingTimeout(element, 0.1)
    }

    func apply(units: Double, direction: RotationDirection) {
        let delta = units * scale * (direction == .clockwise ? 1.0 : -1.0)
        let current = readValue() ?? (minValue + maxValue) / 2
        let newValue = (current + delta).clamped(to: minValue...maxValue)
        writeValue(newValue)
    }

    var displayValue: String? {
        guard let v = readValue() else { return nil }
        return formatDisplayValue(v, min: minValue, max: maxValue)
    }

    // MARK: - AX helpers

    private func readValue() -> Double? {
        var cfValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &cfValue) == .success,
              let number = cfValue as? NSNumber else { return nil }
        return number.doubleValue
    }

    private func writeValue(_ value: Double) {
        let number = NSNumber(value: value)
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, number)
        if result != .success {
            NotificationCenter.default.post(name: .accessibilityPermissionRevoked, object: nil)
        }
    }
}

extension Notification.Name {
    static let accessibilityPermissionRevoked = Notification.Name("com.phantomknob.accessibilityPermissionRevoked")
}
