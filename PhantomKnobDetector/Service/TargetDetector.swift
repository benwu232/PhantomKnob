import Foundation
import AppKit
import ApplicationServices

class TargetDetector {
    static let maxParentDepth = 10
    
    private var lastDetectedTarget: AccessibilityTarget?
    
    init() {}
    
    func detectTargetAtMousePosition() -> AccessibilityTarget? {
        guard AXIsProcessTrusted() else { return nil }
        
        let mouseLocation = NSEvent.mouseLocation
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AnyObject?
        
        let result = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(mouseLocation.x),
            Float(mouseLocation.y),
            &element
        )
        
        guard result == .success, let axElement = element as! AXUIElement? else {
            return nil
        }
        
        if let target = tryCreateTarget(from: axElement) {
            lastDetectedTarget = target
            return target
        }
        
        return findAdjustableParent(of: axElement, depth: 0)
    }
    
    private func findAdjustableParent(of element: AXUIElement, depth: Int) -> AccessibilityTarget? {
        guard depth < Self.maxParentDepth else { return nil }
        
        var parent: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent)
        
        guard result == .success, let parentElement = parent as! AXUIElement? else {
            return nil
        }
        
        if let target = tryCreateTarget(from: parentElement) {
            return target
        }
        
        return findAdjustableParent(of: parentElement, depth: depth + 1)
    }
    
    private func tryCreateTarget(from element: AXUIElement) -> AccessibilityTarget? {
        return AccessibilityTarget(element: element)
    }
    
    func clearCache() {
        lastDetectedTarget = nil
    }
}
