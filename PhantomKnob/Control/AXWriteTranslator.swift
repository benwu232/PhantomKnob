// PhantomKnob/Control/AXWriteTranslator.swift
import Foundation
import ApplicationServices

/// 通过 Accessibility API 直接读-改-写 AXValue。
/// 适用于：系统音量、系统亮度、标准 AXSlider 等 AXValue settable 的控件。
final class AXWriteTranslator: InputTranslator {
    private let element: AXUIElement
    private let minValue: Double
    private let maxValue: Double
    var scale: Double   // 从 ScaleConfig 解析好后传入

    private let invert: Bool

    init(element: AXUIElement, minValue: Double, maxValue: Double, scale: Double = 1.0, invert: Bool = false) {
        self.element = element
        self.minValue = minValue
        self.maxValue = maxValue
        self.scale = scale
        self.invert = invert
        _ = AXUIElementSetMessagingTimeout(element, 0.1)
    }

    func apply(units: Double, direction: RotationDirection) {
        let isCW = invert ? (direction != .clockwise) : (direction == .clockwise)
        let delta = units * scale * (isCW ? 1.0 : -1.0)
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

func formatDisplayValue(_ value: Double, min: Double, max: Double) -> String {
    if max <= 1.0 {
        return "\(Int(value * 100))%"
    }
    
    if min == 0 && max == 100 {
        return "\(Int(value))%"
    }
    
    // 如果是时间轴（max > 1.0），我们提供高精度的亚秒级格式化显示（带 2 位毫秒/帧级小数）
    if max > 1.0 {
        let totalSeconds = value
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let milliseconds = Int(abs(totalSeconds.truncatingRemainder(dividingBy: 1.0)) * 100)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
        }
    }
    
    return "\(Int(value))"
}
