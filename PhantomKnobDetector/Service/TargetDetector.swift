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
        var element: AXUIElement?
        
        _ = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(mouseLocation.x),
            Float(mouseLocation.y),
            &element
        )
        
        guard let axElement = element else { return nil }
        
        if let target = tryCreateTarget(from: axElement) {
            lastDetectedTarget = target
            return target
        }
        
        return findAdjustableParent(of: axElement, depth: 0)
    }
    
    private func findAdjustableParent(of element: AXUIElement, depth: Int) -> AccessibilityTarget? {
        guard depth < Self.maxParentDepth else { return nil }
        
        var parent: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent)
        
        guard let parentRef = parent else { return nil }
        let parentElement = unsafeBitCast(parentRef, to: AXUIElement.self)
        
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
