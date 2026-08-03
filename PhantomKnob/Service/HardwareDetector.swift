import Foundation
import IOKit
import IOKit.hid

struct HardwareDetector {
    /// 检测当前是否连接了触控板（包括内置和外接 Magic Trackpad）
    static func isTrackpadConnected() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        // 匹配触控板的标准 HID 描述符：
        // 1. Digitizer (0x0D) -> Touch Pad (0x05)
        // 2. Generic Desktop (0x01) -> Touch Pad (0x05)
        let matchingDicts: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey: 0x0D,
                kIOHIDDeviceUsageKey: 0x05
            ],
            [
                kIOHIDDeviceUsagePageKey: 0x01,
                kIOHIDDeviceUsageKey: 0x05
            ]
        ]
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDicts as CFArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let devices = IOHIDManagerCopyDevices(manager) else {
            return false
        }
        
        let nsSet = devices as NSSet
        return nsSet.count > 0
    }
    
    /// 异步重试检测触控板，允许开机/登录时外接蓝牙妙控板（Magic Trackpad）有缓冲时间完成连接
    static func checkTrackpadWithRetry(maxAttempts: Int = 5, interval: TimeInterval = 2.0, completion: @escaping (Bool) -> Void) {
        func attempt(remaining: Int) {
            if isTrackpadConnected() {
                completion(true)
                return
            }
            if remaining <= 1 {
                completion(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                attempt(remaining: remaining - 1)
            }
        }
        attempt(remaining: maxAttempts)
    }
}
