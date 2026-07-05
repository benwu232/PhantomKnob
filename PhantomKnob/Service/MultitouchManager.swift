import Foundation
import CoreGraphics
import os

protocol MultitouchEventDelegate: AnyObject {
    func onMultitouchBegan(points: [Int: CGPoint])
    func onMultitouchMoved(points: [Int: CGPoint])
    func onMultitouchEnded()
}

class MultitouchManager {
    static let shared = MultitouchManager()
    
    weak var delegate: MultitouchEventDelegate?
    
    private var device: OpaquePointer?
    private var isRunning = false
    private var handle: UnsafeMutableRawPointer?
    
    // 私有 C 函数类型声明
    private typealias MTDeviceCreateDefaultFunc = @convention(c) () -> OpaquePointer?
    private typealias MTRegisterContactFrameCallbackFunc = @convention(c) (OpaquePointer?, MTContactCallback?) -> Void
    private typealias MTDeviceStartFunc = @convention(c) (OpaquePointer?, Int32) -> Void
    private typealias MTDeviceStopFunc = @convention(c) (OpaquePointer?) -> Void
    private typealias MTDeviceReleaseFunc = @convention(c) (OpaquePointer?) -> Void
    
    private var MTDeviceCreateDefault: MTDeviceCreateDefaultFunc?
    private var MTRegisterContactFrameCallback: MTRegisterContactFrameCallbackFunc?
    private var MTDeviceStart: MTDeviceStartFunc?
    private var MTDeviceStop: MTDeviceStopFunc?
    private var MTDeviceRelease: MTDeviceReleaseFunc?
    
    private init() {
        let libPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        handle = dlopen(libPath, RTLD_NOW)
        
        guard let h = handle else {
            PKLogger.multitouch.error("Failed to dlopen MultitouchSupport.framework")
            return
        }
        
        if let sym = dlsym(h, "MTDeviceCreateDefault") {
            MTDeviceCreateDefault = unsafeBitCast(sym, to: MTDeviceCreateDefaultFunc.self)
        }
        if let sym = dlsym(h, "MTRegisterContactFrameCallback") {
            MTRegisterContactFrameCallback = unsafeBitCast(sym, to: MTRegisterContactFrameCallbackFunc.self)
        }
        if let sym = dlsym(h, "MTDeviceStart") {
            MTDeviceStart = unsafeBitCast(sym, to: MTDeviceStartFunc.self)
        }
        if let sym = dlsym(h, "MTDeviceStop") {
            MTDeviceStop = unsafeBitCast(sym, to: MTDeviceStopFunc.self)
        }
        if let sym = dlsym(h, "MTDeviceRelease") {
            MTDeviceRelease = unsafeBitCast(sym, to: MTDeviceReleaseFunc.self)
        }
        
        PKLogger.multitouch.debug("Dynamic library loaded and C functions bound successfully")
    }
    
    func start() {
        PKLogger.multitouch.debug("start() requested, isRunning: \(self.isRunning)")
        guard !isRunning else { return }
        
        inGesture = false // 🌟 重置手势生命周期状态机变量，确保不会继承过往周期的残留
        
        guard let createDefault = MTDeviceCreateDefault,
              let registerCallback = MTRegisterContactFrameCallback,
              let startDevice = MTDeviceStart else {
            PKLogger.multitouch.error("Start failed: missing bound symbols")
            return
        }
        
        device = createDefault()
        guard let dev = device else {
            PKLogger.multitouch.error("Start failed: failed to create default multitouch device")
            return
        }
        
        let callback: MTContactCallback = { device, contactsRawPtr, numContacts, timestamp, frame in
            PKLogger.multitouch.debug("Raw Callback: numContacts = \(numContacts), frame = \(frame)")
            if let rawPtr = contactsRawPtr {
                let contactsPtr = rawPtr.assumingMemoryBound(to: MTContact.self)
                MultitouchManager.shared.handleContacts(contactsPtr, count: Int(numContacts))
            } else {
                // 🌟 即使 contactsRawPtr 为 nil（通常在 numContacts 为 0 时），也需要驱动 handleContacts 正常执行以进行 inGesture 复位
                MultitouchManager.shared.handleContacts(nil, count: Int(numContacts))
            }
            return 0
        }
        
        registerCallback(dev, callback)
        startDevice(dev, 0)
        isRunning = true
        PKLogger.multitouch.debug("Global background multitouch device start success")
    }
    
    func stop() {
        PKLogger.multitouch.debug("stop() requested, isRunning: \(self.isRunning)")
        guard isRunning, let dev = device, let stopDevice = MTDeviceStop else { return }
        stopDevice(dev)
        
        // 🌟 显式释放底层连接，解决 Mach 端口泄漏导致旋钮使用几轮后失效的系统 slot 耗尽 Bug
        if let releaseDevice = MTDeviceRelease {
            releaseDevice(dev)
        }
        
        device = nil
        isRunning = false
        inGesture = false // 🌟 显式复位手势状态，保障生命周期干净
        PKLogger.multitouch.debug("Stopped global background multitouch monitoring")
    }
    
    // 双指手势生命周期状态机
    private var inGesture = false
    
    private func handleContacts(_ contactsPtr: UnsafeMutablePointer<MTContact>?, count: Int) {
        var activePoints: [Int: CGPoint] = [:]
        
        // 只有当 count > 0 且指针不为空时，才进行触点状态遍历
        if count > 0, let contacts = contactsPtr {
            for i in 0..<count {
                let contact = contacts[i]
                // 印出所有手指的 state 信息用于诊断
                PKLogger.multitouch.debug("Contact[\(i)]: ID = \(contact.identifier), state = \(contact.state), pos = (\(contact.normalized.pos.x), \(contact.normalized.pos.y))")
                
                // state 的取值范围说明：
                // 0 = not touching (空插槽)
                // 1 = starting (手指刚接触)
                // 2 = hovering (悬停，如果硬件支持)
                // 3 = making (开始触碰)
                // 4 = touching (正在稳定触碰)
                // 5 = breaking (手指离开/断开接触)
                // 6 = lingering (残留接触)
                // 7 = leaving (完全离开)
                // 为了最安全的捕获，我们将 1 至 6 均视为有效的活动或边缘触控状态，全面对接手指在触控板上的动作
                if contact.state >= 1 && contact.state <= 6 {
                    let id = Int(contact.identifier)
                    let x = CGFloat(contact.mm.pos.x)
                    let y = CGFloat(contact.mm.pos.y)
                    activePoints[id] = CGPoint(x: x, y: y)
                }
            }
        }
        
        PKLogger.multitouch.debug("handleContacts: activePoints count = \(activePoints.count), inGesture = \(self.inGesture)")
        
        // 当触控板上有且至少有 2 根手指活动时，激活或更新旋钮手势
        if activePoints.count >= 2 {
            if !inGesture {
                inGesture = true
                PKLogger.multitouch.debug("Gesture trigger: onMultitouchBegan with points = \(String(describing: activePoints))")
                DispatchQueue.main.async {
                    self.delegate?.onMultitouchBegan(points: activePoints)
                }
            } else {
                PKLogger.multitouch.debug("Gesture trigger: onMultitouchMoved with points = \(String(describing: activePoints))")
                DispatchQueue.main.async {
                    self.delegate?.onMultitouchMoved(points: activePoints)
                }
            }
        } else if activePoints.count == 1 {
            if inGesture {
                // 🌟 核心改进：当处于手势中且降为单指时，延续旋钮手势，继续发送 Moved 事件
                PKLogger.multitouch.debug("Gesture trigger: onMultitouchMoved (1 finger) with points = \(String(describing: activePoints))")
                DispatchQueue.main.async {
                    self.delegate?.onMultitouchMoved(points: activePoints)
                }
            }
        } else if activePoints.count == 0 {
            // 🌟 当触碰点归零时，说明所有手指完全抬起，立即无延迟终止手势
            if inGesture {
                inGesture = false
                PKLogger.multitouch.debug("Gesture trigger: onMultitouchEnded (Immediate - 0 fingers)")
                DispatchQueue.main.async {
                    self.delegate?.onMultitouchEnded()
                }
            }
        }
    }
    
    deinit {
        stop()
        if let h = handle {
            dlclose(h)
        }
    }
}

// MARK: - MultitouchSupport.framework 底层 C 结构体与类型声明

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTReadout {
    var pos: MTPoint
    var vel: MTPoint
}

// 基于 macOS 12+ x86_64/arm64 真实反编译与社区最佳实践的真实 96 字节 MTContact/Finger 结构体
struct MTContact {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var foo3: Int32
    var foo4: Int32
    var normalized: MTReadout // 16 字节 (pos + vel)
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var mm: MTReadout // 16 字节 (pos + vel)
    var zero2_1: Int32
    var zero2_2: Int32
    var unk2: Float
}

typealias MTContactCallback = @convention(c) (
    _ device: OpaquePointer?,
    _ contacts: UnsafeMutableRawPointer?,
    _ numContacts: Int32,
    _ timestamp: Double,
    _ frame: Int32
) -> Int32
