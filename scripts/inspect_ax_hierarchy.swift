import Foundation
import Cocoa
import ApplicationServices

print("=== AX Hierarchy Inspector ===")

func inspectHierarchy(label: String) {
    let mouseLocation = NSEvent.mouseLocation
    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
    let flippedY = screenHeight - mouseLocation.y
    
    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    let res = AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &element)
    
    print("\n--- [\(label)] Mouse: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y))) ---")
    if res == .success, var current = element {
        var depth = 0
        while depth < 12 {
            var role = ""
            var title = ""
            var val: AnyObject?
            
            if AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &val) == .success { role = val as? String ?? "" }
            if AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &val) == .success { title = val as? String ?? "" }
            
            print("  Depth \(depth): Role = \(role), Title = '\(title)'")
            
            var parent: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
               let parentRef = parent {
                current = unsafeBitCast(parentRef, to: AXUIElement.self)
                depth += 1
            } else {
                break
            }
        }
    } else {
        print("  No element found under cursor.")
    }
}

print("Phase 1: Hover over COLOR WHEEL dial now...")
for i in (1...5).reversed() {
    print("Capturing COLOR WHEEL in \(i)s...")
    Thread.sleep(forTimeInterval: 1.0)
}
inspectHierarchy(label: "COLOR WHEEL")

print("\nPhase 2: Move mouse and hover over TIMELINE / VIEWER now...")
for i in (1...5).reversed() {
    print("Capturing TIMELINE in \(i)s...")
    Thread.sleep(forTimeInterval: 1.0)
}
inspectHierarchy(label: "TIMELINE/VIEWER")
