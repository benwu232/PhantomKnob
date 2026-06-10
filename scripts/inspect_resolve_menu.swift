import Foundation
import Cocoa
import ApplicationServices

print("=== Resolve Menu Inspector ===")

// 寻找 DaVinci Resolve 进程
let apps = NSWorkspace.shared.runningApplications
guard let resolveApp = apps.first(where: { $0.bundleIdentifier == "com.blackmagic-design.DaVinciResolve" }) else {
    print("Error: DaVinci Resolve is not running.")
    exit(1)
}

let pid = resolveApp.processIdentifier
let appElement = AXUIElementCreateApplication(pid)
_ = AXUIElementSetMessagingTimeout(appElement, 0.5)

var menuBarVal: AnyObject?
guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarVal) == .success,
      let menuBar = menuBarVal else {
    print("Error: Could not copy menu bar. Please make sure accessibility permissions are enabled.")
    exit(1)
}

let menuBarElement = unsafeBitCast(menuBar, to: AXUIElement.self)

// 递归遍历菜单项并寻找带有勾选（AXValue == 1）的页面切换选项
func dumpMenu(element: AXUIElement, path: String) {
    var roleVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
    let role = roleVal as? String ?? ""
    
    var titleVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
    let title = titleVal as? String ?? ""
    
    var valueVal: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueVal)
    
    let currentPath = path.isEmpty ? title : "\(path) -> \(title)"
    
    if role == "AXMenuItem" {
        // 打印有标题的菜单项
        if !title.isEmpty {
            var checkedStr = ""
            if let number = valueVal as? NSNumber, number.intValue == 1 {
                checkedStr = " [CHECKED]"
            }
            // 打印 Workspace 相关的子项
            if currentPath.contains("Workspace") || currentPath.contains("工作区") || !checkedStr.isEmpty {
                print("Menu: \(currentPath)\(checkedStr)")
            }
        }
    }
    
    var childrenVal: AnyObject?
    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
       let children = childrenVal as? [AnyObject] {
        for child in children {
            let childElement = unsafeBitCast(child, to: AXUIElement.self)
            dumpMenu(element: childElement, path: currentPath)
        }
    }
}

print("Dumping DaVinci Resolve Menu Bar...")
dumpMenu(element: menuBarElement, path: "")
