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
        self.sensitivity = sensitivity
        
        guard let role = self.getStringValue(for: kAXRoleAttribute) else {
            return nil
        }
        
        self.controlType = ControlType.fromAXRole(role)
        
        guard let min = self.getDoubleValue(for: kAXMinValueAttribute),
              let max = self.getDoubleValue(for: kAXMaxValueAttribute) else {
            return nil
        }
        
        self.minValue = min
        self.maxValue = max
        
        self.displayName = self.getStringValue(for: kAXTitleAttribute)
            ?? self.getStringValue(for: kAXDescriptionAttribute)
            ?? role
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
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        guard result == .success, let number = value as? NSNumber else {
            return nil
        }
        
        return number.doubleValue
    }
    
    private func setDoubleValue(_ newValue: Double) {
        var val = newValue
        let axValue = AXValueCreate(.cgFloat, &val)
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, axValue)
    }
    
    private func getStringValue(for attribute: String) -> String? {
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
    if min == 0 && max == 100 {
        return "\(Int(value))%"
    }
    
    if min == 0 && max >= 3600 {
        let hours = Int(value) / 3600
        let minutes = (Int(value) % 3600) / 60
        let seconds = Int(value) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    return "\(Int(value))"
}
