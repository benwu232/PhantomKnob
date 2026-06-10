import Foundation
import Cocoa
import ApplicationServices

print("=== DaVinci Resolve Accessibility Inspector (Looping) ===")
print("Move your mouse around. The script will print the hovered element under the cursor every 1 second for 15 seconds...\n")

for i in 1...15 {
    let mouseLocation = NSEvent.mouseLocation
    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
    let flippedY = screenHeight - mouseLocation.y
    
    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    let res = AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &element)
    
    var appInfo = "No app"
    var axDetails = "No AXElement"
    
    if res == .success, let axElement = element {
        var pid: pid_t = 0
        if AXUIElementGetPid(axElement, &pid) == .success {
            let app = NSRunningApplication(processIdentifier: pid)
            appInfo = "\(app?.localizedName ?? "Unknown") (\(app?.bundleIdentifier ?? "no-id"))"
        }
        
        var role = ""
        var subrole = ""
        var title = ""
        var desc = ""
        var identifier = ""
        
        var val: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &val) == .success { role = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(axElement, kAXSubroleAttribute as CFString, &val) == .success { subrole = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &val) == .success { title = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(axElement, kAXDescriptionAttribute as CFString, &val) == .success { desc = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(axElement, kAXIdentifierAttribute as CFString, &val) == .success { identifier = val as? String ?? "" }
        
        axDetails = "Role: \(role), Subrole: \(subrole), Title: '\(title)', Desc: '\(desc)', ID: '\(identifier)'"
    }
    
    print("[\(i)/15] Mouse: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y))) | Hovered App: \(appInfo) | AX: \(axDetails)")
    Thread.sleep(forTimeInterval: 1.0)
}
