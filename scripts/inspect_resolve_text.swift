import Foundation
import Cocoa
import ApplicationServices

print("=== Resolve Text Element Scanner ===")

let apps = NSWorkspace.shared.runningApplications
guard let resolveApp = apps.first(where: { $0.bundleIdentifier == "com.blackmagic-design.DaVinciResolve" }) else {
    print("Error: DaVinci Resolve is not running.")
    exit(1)
}

let pid = resolveApp.processIdentifier
let appElement = AXUIElementCreateApplication(pid)

// 获取主窗口
var windowVal: AnyObject?
guard AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &windowVal) == .success,
      let mainWindow = windowVal else {
    print("Error: Could not find main window of DaVinci Resolve.")
    exit(1)
}

let windowElement = unsafeBitCast(mainWindow, to: AXUIElement.self)

var foundCount = 0

func searchElements(element: AXUIElement, depth: Int) {
    if depth > 12 { return } // 深度限制
    
    var roleVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
    let role = roleVal as? String ?? ""
    
    var titleVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
    let title = titleVal as? String ?? ""
    
    var descVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descVal)
    let desc = descVal as? String ?? ""
    
    let tLower = title.lowercased()
    let dLower = desc.lowercased()
    
    if tLower.contains("wheel") || tLower.contains("color") || tLower.contains("primary") ||
       dLower.contains("wheel") || dLower.contains("color") || dLower.contains("primary") {
        print("Found matching element at depth \(depth):")
        print("  Role: \(role)")
        print("  Title: '\(title)'")
        print("  Description: '\(desc)'")
        foundCount += 1
    }
    
    var childrenVal: AnyObject?
    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
       let children = childrenVal as? [AnyObject] {
        for child in children {
            let childElement = unsafeBitCast(child, to: AXUIElement.self)
            searchElements(element: childElement, depth: depth + 1)
        }
    }
}

print("Scanning DaVinci Resolve window hierarchy (this may take a few seconds)...")
searchElements(element: windowElement, depth: 0)
print("Scan complete. Found \(foundCount) matching elements.")
