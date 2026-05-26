#!/usr/bin/swift
import Foundation
import Cocoa
import ApplicationServices

print("=== Global Event Monitor Diagnostic Tool ===")
print("This tool will print any global event captured. Move mouse, click, or swipe trackpad to test.")
print("Press Ctrl+C to exit.")

guard AXIsProcessTrusted() else {
    print("\n❌ Error: Accessibility permissions are not granted for this Terminal.")
    print("Please grant permission in System Settings -> Privacy & Security -> Accessibility.")
    exit(1)
}

// Setup global run loop
let runLoop = CFRunLoopGetCurrent()

// We will monitor:
// 1. .gesture (1 << 29)
// 2. .directTouch (1 << 37)
// 3. raw 1 << 38 (indirect touches)
// 4. raw 1 << 18 (rotate gesture)
// 5. raw 1 << 19 (magnify gesture)
// 6. .mouseMoved (1 << 5) to verify if the monitor works at all!

let gestureMask = NSEvent.EventTypeMask.gesture
let directTouchMask = NSEvent.EventTypeMask.directTouch
let indirectTouchesMask = NSEvent.EventTypeMask(rawValue: 1 << 38)
let rotateMask = NSEvent.EventTypeMask(rawValue: 1 << 18)
let magnifyMask = NSEvent.EventTypeMask(rawValue: 1 << 19)
let mouseMovedMask = NSEvent.EventTypeMask.mouseMoved

let combinedMask = NSEvent.EventTypeMask([gestureMask, directTouchMask])
    .union(indirectTouchesMask)
    .union(rotateMask)
    .union(magnifyMask)
    .union(mouseMovedMask)

print("Starting Global Monitor with mask rawValue: \(combinedMask.rawValue)...")

var eventCount = 0
let monitor = NSEvent.addGlobalMonitorForEvents(matching: combinedMask) { event in
    eventCount += 1
    
    let typeRaw = event.type.rawValue
    let typeStr: String
    switch event.type {
    case .gesture: typeStr = "gesture (29)"
    case .directTouch: typeStr = "directTouch (37)"
    case .mouseMoved: typeStr = "mouseMoved (5)"
    default:
        if typeRaw == 38 {
            typeStr = "indirectTouches (38)"
        } else if typeRaw == 18 {
            typeStr = "rotate gesture (18)"
        } else if typeRaw == 19 {
            typeStr = "magnify gesture (19)"
        } else {
            typeStr = "Other (\(typeRaw))"
        }
    }
    
    // Print details of the event
    print("[\(eventCount)] Captured Event: \(typeStr)")
    
    if typeRaw == 38 || event.type == .gesture || event.type == .directTouch {
        let touches = event.touches(matching: .any, in: nil)
        print("  - Touches count: \(touches.count)")
        for (idx, touch) in touches.enumerated() {
            let pos = touch.normalizedPosition
            print("    * Touch \(idx): phase=\(touch.phase), pos=(\(pos.x), \(pos.y))")
        }
    } else if typeRaw == 18 {
        print("  - Rotation: \(event.rotation)")
    } else if typeRaw == 19 {
        print("  - Magnification: \(event.magnification)")
    }
}

// Keep the script running
CFRunLoopRun()
