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
}
