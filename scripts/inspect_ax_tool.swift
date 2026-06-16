#!/usr/bin/swift
import Foundation
import Cocoa
import ApplicationServices

print("=== 通用 AX 元素独立诊断工具 ===")
print("1. 请确保已赋予终端 Accessibility (辅助功能) 权限。")
print("2. 切换到目标应用，将鼠标移至目标元素上。")
print("3. 可以使用以下两种方式触发检测：")
print("   - 【方式 A】直接左键点击该元素")
print("   - 【方式 B】按下组合键 Control + Shift + D")
print("4. 检测结果将实时打印并追加保存至当前目录下的 inspect_results.txt。")
print("按 Ctrl + C 可以保存并退出。\n")

guard AXIsProcessTrusted() else {
    print("❌ Error: 终端未获得辅助功能权限！")
    print("请前往：系统设置 -> 隐私与安全 -> 辅助功能，勾选当前终端。")
    exit(1)
}

let logURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("inspect_results.txt")

func appendLog(_ text: String) {
    print(text)
    if let data = (text + "\n").data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logURL)
        }
    }
}

func inspectElementAtMouse() {
    let mouseLocation = NSEvent.mouseLocation
    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
    let flippedY = screenHeight - mouseLocation.y
    
    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    let res = AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &element)
    
    guard res == .success, let axElement = element else {
        print("⚠️ 未能在坐标 (\(Int(mouseLocation.x)), \(Int(mouseLocation.y))) 处捕获到任何元素")
        return
    }
    
    var pid: pid_t = 0
    var appName = "Unknown"
    var bundleID = "unknown-bundle"
    if AXUIElementGetPid(axElement, &pid) == .success {
        let app = NSRunningApplication(processIdentifier: pid)
        appName = app?.localizedName ?? "Unknown"
        bundleID = app?.bundleIdentifier ?? "unknown-bundle"
    }
    
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
    var output = "\n========================================\n"
    output += "时间: \(timestamp)\n"
    output += "坐标: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y)))\n"
    output += "应用: \(appName) (\(bundleID))\n"
    output += "---------------- 层级树 ----------------\n"
    
    var current = axElement
    var depth = 0
    var leafRole = "unknown"
    
    while depth < 10 {
        var role = "unknown"
        var subrole = ""
        var title = ""
        var desc = ""
        var identifier = ""
        var value: AnyObject?
        var minValue: Double?
        var maxValue: Double?
        
        var val: AnyObject?
        if AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &val) == .success { role = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(current, kAXSubroleAttribute as CFString, &val) == .success { subrole = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &val) == .success { title = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(current, kAXDescriptionAttribute as CFString, &val) == .success { desc = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(current, kAXIdentifierAttribute as CFString, &val) == .success { identifier = val as? String ?? "" }
        if AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &value) != .success { value = nil }
        
        if depth == 0 {
            leafRole = role
        }
        
        var num: AnyObject?
        if AXUIElementCopyAttributeValue(current, kAXMinValueAttribute as CFString, &num) == .success, let n = num as? NSNumber {
            minValue = n.doubleValue
        }
        if AXUIElementCopyAttributeValue(current, kAXMaxValueAttribute as CFString, &num) == .success, let n = num as? NSNumber {
            maxValue = n.doubleValue
        }
        
        output += "Depth \(depth): Role = \(role)"
        if !subrole.isEmpty { output += ", Subrole = \(subrole)" }
        if !title.isEmpty { output += ", Title = '\(title)'" }
        if !desc.isEmpty { output += ", Desc = '\(desc)'" }
        if !identifier.isEmpty { output += ", ID = '\(identifier)'" }
        if let v = value { output += ", Value = \(v)" }
        if let minv = minValue, let maxv = maxValue { output += ", Min/Max = (\(minv), \(maxv))" }
        output += "\n"
        
        var parent: CFTypeRef?
        if AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
           let parentRef = parent {
            current = unsafeBitCast(parentRef, to: AXUIElement.self)
            depth += 1
        } else {
            break
        }
    }
    
    output += "---------------- 规则推荐 ----------------\n"
    output += "建议将以下 JSON 加入 PhantomKnob 规则库:\n"
    output += """
    {
      "key": {
        "bundleID": "\(bundleID)",
        "axRole": "\(leafRole)",
        "identifier": null
      },
      "translation": "arrowKeyUpDown",
      "scaleConfig": {
        "fixed": 1.0
      }
    }
    """
    output += "\n========================================\n"
    
    appendLog(output)
}

// 键盘与鼠标全局监听
let eventMask = NSEvent.EventTypeMask([.leftMouseUp, .keyDown])
let monitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { event in
    if event.type == .leftMouseUp {
        // 鼠标点击触发
        inspectElementAtMouse()
    } else if event.type == .keyDown {
        // 热键检测 Control + Shift + D (d 的 charactersIgnoringModifiers)
        let flags = event.modifierFlags
        if flags.contains(.control) && flags.contains(.shift) && event.charactersIgnoringModifiers == "d" {
            inspectElementAtMouse()
        }
    }
}

CFRunLoopRun()
