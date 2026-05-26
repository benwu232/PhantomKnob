#!/usr/bin/swift
import Foundation
import Cocoa
import ApplicationServices

print("=== QuickTime Progress Bar Detection Test ===")
print("Please hover your mouse over the QuickTime playback progress bar now.")
print("Starting detection in 3 seconds...")

for i in (1...3).reversed() {
    print("\(i)...")
    Thread.sleep(forTimeInterval: 1.0)
}

guard AXIsProcessTrusted() else {
    print("\n❌ Error: Accessibility permissions are not granted for the terminal running this script.")
    print("Please grant accessibility permissions, then run this again.")
    exit(1)
}

let mouseLocation = NSEvent.mouseLocation
var screenHeight: CGFloat = 1080
if let mainScreen = NSScreen.main {
    screenHeight = mainScreen.frame.height
}
// Convert to Carbon/AX coordinates (Y is down)
let axY = screenHeight - mouseLocation.y
let mousePoint = CGPoint(x: mouseLocation.x, y: axY)

print("\nMouse Location (Cocoa): \(mouseLocation)")
print("Mouse Location (AX/Carbon): \(mousePoint)")

let systemWideElement = AXUIElementCreateSystemWide()
var elementRef: AXUIElement?

let result = AXUIElementCopyElementAtPosition(
    systemWideElement,
    Float(mouseLocation.x),
    Float(axY),
    &elementRef
)

guard result == .success, let hitElement = elementRef else {
    print("❌ Failed to get element under mouse. AX error: \(result.rawValue)")
    exit(1)
}

func getAttributeString(_ element: AXUIElement, _ attribute: String) -> String? {
    var val: AnyObject?
    let res = AXUIElementCopyAttributeValue(element, attribute as CFString, &val)
    if res == .success, let str = val as? String {
        return str
    }
    return nil
}

func getAttributeDouble(_ element: AXUIElement, _ attribute: String) -> Double? {
    var val: AnyObject?
    let res = AXUIElementCopyAttributeValue(element, attribute as CFString, &val)
    if res == .success, let num = val as? NSNumber {
        return num.doubleValue
    }
    return nil
}

func getElementFrame(_ element: AXUIElement) -> CGRect? {
    var posRef: CFTypeRef?
    let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)
    
    var sizeRef: CFTypeRef?
    let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
    
    guard posResult == .success, let posVal = posRef,
          sizeResult == .success, let sizeVal = sizeRef else {
        return nil
    }
    
    var point = CGPoint.zero
    AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
    
    var size = CGSize.zero
    AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
    
    return CGRect(origin: point, size: size)
}

let hitRole = getAttributeString(hitElement, kAXRoleAttribute) ?? "Unknown"
let hitTitle = getAttributeString(hitElement, kAXTitleAttribute) ?? "nil"
print("Direct Hit-Test Element: Role = \(hitRole), Title = \(hitTitle)")

// Find the containing window
func findContainingWindow(of element: AXUIElement) -> AXUIElement? {
    let role = getAttributeString(element, kAXRoleAttribute)
    if role == "AXWindow" {
        return element
    }
    
    var parent: CFTypeRef?
    let res = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent)
    if res == .success, let parentRef = parent {
        let parentElement = unsafeBitCast(parentRef, to: AXUIElement.self)
        return findContainingWindow(of: parentElement)
    }
    return nil
}

guard let rootWindow = findContainingWindow(of: hitElement) else {
    print("❌ Could not find a containing AXWindow for the element.")
    exit(1)
}

let winTitle = getAttributeString(rootWindow, kAXTitleAttribute) ?? "nil"
print("Found Containing Window: Title = \(winTitle)")

// Recursively traverse window children and collect all elements
struct Candidate {
    let element: AXUIElement
    let role: String
    let subrole: String?
    let title: String?
    let frame: CGRect
    let value: Double?
    let minValue: Double?
    let maxValue: Double?
}

var allCandidates: [Candidate] = []

func traverse(element: AXUIElement, depth: Int, maxDepth: Int) {
    if depth > maxDepth { return }
    
    let role = getAttributeString(element, kAXRoleAttribute) ?? "Unknown"
    let subrole = getAttributeString(element, kAXSubroleAttribute)
    let title = getAttributeString(element, kAXTitleAttribute)
    let frame = getElementFrame(element)
    
    let val = getAttributeDouble(element, kAXValueAttribute)
    let minVal = getAttributeDouble(element, kAXMinValueAttribute)
    let maxVal = getAttributeDouble(element, kAXMaxValueAttribute)
    
    if let frame = frame {
        let candidate = Candidate(
            element: element,
            role: role,
            subrole: subrole,
            title: title,
            frame: frame,
            value: val,
            minValue: minVal,
            maxValue: maxVal
        )
        allCandidates.append(candidate)
    }
    
    var childrenRef: CFTypeRef?
    let res = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
    if res == .success, let children = childrenRef as? [AXUIElement] {
        for child in children {
            traverse(element: child, depth: depth + 1, maxDepth: maxDepth)
        }
    }
}

print("Traversing the accessibility tree under the window (max depth 8)...")
traverse(element: rootWindow, depth: 0, maxDepth: 8)
print("Traversal complete. Total elements with frames found: \(allCandidates.count)")

func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    if rect.contains(point) {
        return 0
    }
    let closestX = max(rect.minX, min(point.x, rect.maxX))
    let closestY = max(rect.minY, min(point.y, rect.maxY))
    let dx = point.x - closestX
    let dy = point.y - closestY
    return sqrt(dx * dx + dy * dy)
}

print("\n--- Analysing Candidates ---")
var adjustableCandidates: [(Candidate, CGFloat)] = []

for cand in allCandidates {
    // We consider it adjustable if it has minValue, maxValue, and value, OR if role is AXSlider
    let isAdjustable = (cand.minValue != nil && cand.maxValue != nil && cand.value != nil) || cand.role == "AXSlider"
    
    if isAdjustable {
        let dist = distance(from: mousePoint, to: cand.frame)
        adjustableCandidates.append((cand, dist))
        
        print("Candidate: Role=\(cand.role), Subrole=\(cand.subrole ?? "nil"), Title=\(cand.title ?? "nil"), Frame=\(cand.frame)")
        print("  - Value: \(cand.value ?? -999) (Min: \(cand.minValue ?? -999), Max: \(cand.maxValue ?? -999))")
        print("  - Distance to mouse: \(dist) px")
    }
}

if adjustableCandidates.isEmpty {
    print("\n❌ No adjustable elements (AXSlider, etc.) found anywhere in this window's AX tree!")
} else {
    print("\n--- Closest Adjustable Element Decision ---")
    adjustableCandidates.sort { $0.1 < $1.1 }
    let (bestCand, bestDist) = adjustableCandidates.first!
    print("🏆 Best Match: Role=\(bestCand.role), Title=\(bestCand.title ?? "nil"), Frame=\(bestCand.frame)")
    print("  - Value: \(bestCand.value ?? -999) (Min: \(bestCand.minValue ?? -999), Max: \(bestCand.maxValue ?? -999))")
    print("  - Distance to mouse: \(bestDist) px")
    
    if bestDist <= 50.0 {
        print("\n✅ SUCCESS: Within 50px threshold! This element WOULD BE CAPTURED as active target!")
    } else {
        print("\n⚠️ WARNING: Distance \(bestDist) px exceeds the 50px threshold. It would NOT be captured. You might need to adjust the threshold or double check mouse hover position.")
    }
}
