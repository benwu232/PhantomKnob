import Foundation
import AppKit
import ApplicationServices

class AccessibilityTarget: ControlTarget {
    let element: AXUIElement
    let controlType: ControlType
    
    var value: Double {
        get { return getDoubleValue(for: kAXValueAttribute) ?? 0 }
        set { setDoubleValue(newValue) }
    }
    
    let minValue: Double
    let maxValue: Double
    let displayName: String
    
    private let sensitivity: Double
    
    init?(element: AXUIElement, sensitivity: Double = 0.5) {
        self.element = element
        
        guard let role = Self.getStringValue(from: element, for: kAXRoleAttribute) else {
            return nil
        }
        
        self.controlType = ControlType.fromAXRole(role)
        
        guard let min = Self.getDoubleValue(from: element, for: kAXMinValueAttribute),
              let max = Self.getDoubleValue(from: element, for: kAXMaxValueAttribute) else {
            return nil
        }
        
        self.minValue = min
        self.maxValue = max
        
        self.displayName = Self.getStringValue(from: element, for: kAXTitleAttribute)
            ?? Self.getStringValue(from: element, for: kAXDescriptionAttribute)
            ?? role
        
        // 自适应灵敏度配置：依据可调整范围智能匹配旋转比率
        let range = abs(max - min)
        if range <= 1.0 {
            // 当范围是 0-1 时（例如音量），设定每 1° 对应 1%（即灵敏度为 0.01）
            self.sensitivity = 0.01
        } else if range <= 100.0 {
            // 当范围是 0-100 时，设定每 1° 对应 1%（即灵敏度为 1.0）
            self.sensitivity = 1.0
        } else {
            // 其他大跨度滑块，使用平滑比例（转一整圈 360° 刚好走满整个范围）
            self.sensitivity = range / 360.0
        }
    }
    
    func applyDelta(_ deltaAngle: Double) -> Double {
        let delta = deltaAngle * sensitivity
        let newValue = (value + delta).clamped(to: minValue...maxValue)
        value = newValue
        return newValue
    }
    
    func displayValue() -> String {
        return formatDisplayValue(value, min: minValue, max: maxValue)
    }
    
    private func getDoubleValue(for attribute: String) -> Double? {
        return Self.getDoubleValue(from: element, for: attribute)
    }
    
    private static func getDoubleValue(from element: AXUIElement, for attribute: String) -> Double? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        guard result == .success, let number = value as? NSNumber else {
            return nil
        }
        
        return number.doubleValue
    }
    
    private func setDoubleValue(_ newValue: Double) {
        let number = NSNumber(value: newValue)
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, number)
    }
    
    private func getStringValue(for attribute: String) -> String? {
        return Self.getStringValue(from: element, for: attribute)
    }
    
    private static func getStringValue(from element: AXUIElement, for attribute: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        guard result == .success, let string = value as? String else {
            return nil
        }
        
        return string
    }
}

extension ControlType {
    static func fromAXRole(_ role: String) -> ControlType {
        switch role {
        case "AXSlider": return .slider
        case "AXProgressIndicator": return .progressIndicator
        case "AXScrollBar": return .scrollbar
        default: return .unknown
        }
    }
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
