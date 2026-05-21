#!/usr/bin/swift
import Foundation
import Cocoa
import ApplicationServices

print("=== Accessibility UI Element Inspector ===")
print("Please hover your mouse over the target UI element (e.g., QuickTime playback progress bar)")
print("Starting inspection in 3 seconds... Move your mouse there now!")

for i in (1...3).reversed() {
    print("\(i)...")
    Thread.sleep(forTimeInterval: 1.0)
}

guard AXIsProcessTrusted() else {
    print("\n❌ Error: Accessibility permissions are not granted for the terminal/process running this script.")
    print("Please grant permission to Terminal/VSCode/your IDE in System Settings -> Privacy & Security -> Accessibility, then try again.")
    exit(1)
}

let mouseLocation = NSEvent.mouseLocation
// In Cocoa, Y is up, but AX API expects screen coordinates where Y is down (origin top-left).
// Let's get the screen height to convert.
var screenHeight: CGFloat = 1080
if let mainScreen = NSScreen.main {
    screenHeight = mainScreen.frame.height
}
let axY = screenHeight - mouseLocation.y

print("\nMouse Cocoa Position: (\(mouseLocation.x), \(mouseLocation.y))")
print("Converted Screen Position: (\(mouseLocation.x), \(axY))")

let systemWideElement = AXUIElementCreateSystemWide()
var elementRef: AXUIElement?

let result = AXUIElementCopyElementAtPosition(
    systemWideElement,
    Float(mouseLocation.x),
    Float(axY),
    &elementRef
)

guard result == .success, let element = elementRef else {
    print("❌ Failed to copy element at position. Error: \(result.rawValue)")
    exit(1)
}

func printAttributes(of el: AXUIElement, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)
    
    var role: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
    
    var subrole: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXSubroleAttribute as CFString, &subrole)
    
    var title: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &title)
    
    var desc: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &desc)
    
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &value)
    
    var minValue: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXMinValueAttribute as CFString, &minValue)
    
    var maxValue: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXMaxValueAttribute as CFString, &maxValue)
    
    print("\(indent)--- Level \(depth) Element ---")
    print("\(indent)Role: \(role ?? "nil")")
    print("\(indent)Subrole: \(subrole ?? "nil")")
    print("\(indent)Title: \(title ?? "nil")")
    print("\(indent)Description: \(desc ?? "nil")")
    print("\(indent)Value: \(value ?? "nil") (Type: \(value != nil ? String(describing: type(of: value!)) : "nil"))")
    print("\(indent)MinValue: \(minValue ?? "nil") (Type: \(minValue != nil ? String(describing: type(of: minValue!)) : "nil"))")
    print("\(indent)MaxValue: \(maxValue ?? "nil") (Type: \(maxValue != nil ? String(describing: type(of: maxValue!)) : "nil"))")
    
    // Check if it is considered adjustable
    let hasMin = minValue != nil
    let hasMax = maxValue != nil
    let hasVal = value != nil
    print("\(indent)Is Controllable Target: \(hasMin && hasMax && hasVal)")
    
    // Let's traverse to the parent up to 3 levels to see the hierarchy
    if depth < 3 {
        var parent: CFTypeRef?
        let parentResult = AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent)
        if parentResult == .success, let parentRef = parent {
            let parentElement = unsafeBitCast(parentRef, to: AXUIElement.self)
            printAttributes(of: parentElement, depth: depth + 1)
        }
    }
}

printAttributes(of: element)
