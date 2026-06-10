import Foundation
import Cocoa
import ApplicationServices

print("=== Resolve Menu Item Detail Inspector ===")

let apps = NSWorkspace.shared.runningApplications
guard let resolveApp = apps.first(where: { $0.bundleIdentifier == "com.blackmagic-design.DaVinciResolve" }) else {
    print("Error: DaVinci Resolve is not running.")
    exit(1)
}

let pid = resolveApp.processIdentifier
let appElement = AXUIElementCreateApplication(pid)

var menuBarVal: AnyObject?
guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarVal) == .success,
      let menuBar = menuBarVal else {
    print("Error: Could not copy menu bar.")
    exit(1)
}

let menuBarElement = unsafeBitCast(menuBar, to: AXUIElement.self)

func inspectTargetMenuItems(element: AXUIElement, path: String) {
    var roleVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
    let role = roleVal as? String ?? ""
    
    var titleVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
    let title = titleVal as? String ?? ""
    
    let currentPath = path.isEmpty ? title : "\(path) -> \(title)"
    
    if role == "AXMenuItem" && (title == "Color" || title == "Edit" || title == "Cut") && path.contains("Switch to Page") {
        print("\nFound Target Menu Item: \(currentPath)")
        
        var attrNames: CFArray?
        if AXUIElementCopyAttributeNames(element, &attrNames) == .success,
           let names = attrNames as? [String] {
            for name in names {
                var val: AnyObject?
                if AXUIElementCopyAttributeValue(element, name as CFString, &val) == .success,
                   let v = val {
                    print("  \(name): \(v)")
                } else {
                    print("  \(name): (null/error)")
                }
            }
        }
    }
    
    var childrenVal: AnyObject?
    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
       let children = childrenVal as? [AnyObject] {
        for child in children {
            let childElement = unsafeBitCast(child, to: AXUIElement.self)
            inspectTargetMenuItems(element: childElement, path: currentPath)
        }
    }
}

inspectTargetMenuItems(element: menuBarElement, path: "")
