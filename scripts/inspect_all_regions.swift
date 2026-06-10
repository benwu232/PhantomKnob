import Foundation
import Cocoa
import ApplicationServices

print("=== Resolve Multi-Region Inspector ===")

func inspectRegion(label: String) {
    let mouseLocation = NSEvent.mouseLocation
    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
    let flippedY = screenHeight - mouseLocation.y
    
    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    let res = AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &element)
    
    print("\n--- [\(label)] Mouse Pos: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y))) ---")
    if res == .success, var current = element {
        var depth = 0
        while depth < 6 {
            var role = ""
            var title = ""
            var frameVal: AnyObject?
            var val: AnyObject?
            
            if AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &val) == .success { role = val as? String ?? "" }
            if AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &val) == .success { title = val as? String ?? "" }
            
            var frameStr = "no frame"
            if AXUIElementCopyAttributeValue(current, "AXFrame" as CFString, &frameVal) == .success,
               let v = frameVal {
                var rect = CGRect.zero
                if AXValueGetValue(v as! AXValue, .cgRect, &rect) {
                    frameStr = "x:\(Int(rect.origin.x)) y:\(Int(rect.origin.y)) w:\(Int(rect.size.width)) h:\(Int(rect.size.height))"
                }
            }
            
            print("  Depth \(depth): Role = \(role), Title = '\(title)', Frame = [\(frameStr)]")
            
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

func countdown(msg: String) {
    print("\n>>> \(msg) <<<")
    for i in (1...5).reversed() {
        print("Capturing in \(i)s...")
        Thread.sleep(forTimeInterval: 1.0)
    }
}

countdown(msg: "1. COLOR PAGE: Hover over COLOR WHEEL (撥輪)")
inspectRegion(label: "COLOR WHEEL")

countdown(msg: "2. COLOR PAGE: Hover over VIDEO VIEWER (調色页监视器)")
inspectRegion(label: "COLOR VIEWER")

countdown(msg: "3. EDIT PAGE: Hover over TIMELINE TRACKS (剪辑页底部时间轴)")
inspectRegion(label: "EDIT TIMELINE")

countdown(msg: "4. EDIT PAGE: Hover over VIDEO VIEWER (剪辑页视频监视器)")
inspectRegion(label: "EDIT VIEWER")
