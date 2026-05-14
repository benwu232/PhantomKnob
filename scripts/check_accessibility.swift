#!/usr/bin/swift
import Foundation
import Cocoa

print("=== 辅助功能权限检查 ===\n")

let isTrusted = AXIsProcessTrusted()
print("1. AXIsProcessTrusted(): \(isTrusted)")

let processName = ProcessInfo.processInfo.processName
let pid = ProcessInfo.processInfo.processIdentifier
print("2. Process Name: \(processName)")
print("3. Process ID: \(pid)")

if let appPath = Bundle.main.executablePath {
    print("4. Executable Path: \(appPath)")
}

print("\n=== 建议 ===")
if isTrusted {
    print("✅ 权限已授予")
} else {
    print("❌ 权限未授予")
    print("\n解决方案：")
    print("1. 打开系统设置 → 隐私与安全性 → 辅助功能")
    print("2. 点击左下角锁图标解锁（需要管理员密码）")
    print("3. 点击 + 按钮添加 PhantomKnobDetector.app")
    print("4. 确保勾选框已勾选")
    print("5. 完全退出应用并重新启动")
}
