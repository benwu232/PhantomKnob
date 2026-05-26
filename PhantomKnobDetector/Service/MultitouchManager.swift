import Foundation
import CoreGraphics

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
    
    private var MTDeviceCreateDefault: MTDeviceCreateDefaultFunc?
    private var MTRegisterContactFrameCallback: MTRegisterContactFrameCallbackFunc?
    private var MTDeviceStart: MTDeviceStartFunc?
    private var MTDeviceStop: MTDeviceStopFunc?
    
    private init() {
        let libPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        handle = dlopen(libPath, RTLD_NOW)
        
        guard let h = handle else {
            writeDebugLog("[MultitouchManager] Critical: Failed to dlopen MultitouchSupport.framework")
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
        
        writeDebugLog("[MultitouchManager] Dynamic library loaded and C functions bound successfully")
    }
    
    func start() {
        writeDebugLog("[MultitouchManager] start() requested, isRunning: \(isRunning)")
        guard !isRunning else { return }
        guard let createDefault = MTDeviceCreateDefault,
              let registerCallback = MTRegisterContactFrameCallback,
              let startDevice = MTDeviceStart else {
            writeDebugLog("[MultitouchManager] Start failed: missing bound symbols")
            return
        }
        
        device = createDefault()
        guard let dev = device else {
            writeDebugLog("[MultitouchManager] Start failed: failed to create default multitouch device")
            return
        }
        
        let callback: MTContactCallback = { device, contactsRawPtr, numContacts, timestamp, frame in
            writeDebugLog("[MultitouchManager] Raw Callback: numContacts = \(numContacts), frame = \(frame)")
            if let rawPtr = contactsRawPtr {
                let contactsPtr = rawPtr.assumingMemoryBound(to: MTContact.self)
                MultitouchManager.shared.handleContacts(contactsPtr, count: Int(numContacts))
            }
            return 0
        }
        
        registerCallback(dev, callback)
        startDevice(dev, 0)
        isRunning = true
        writeDebugLog("[MultitouchManager] Global background multitouch device start success")
    }
    
    func stop() {
        writeDebugLog("[MultitouchManager] stop() requested, isRunning: \(isRunning)")
        guard isRunning, let dev = device, let stopDevice = MTDeviceStop else { return }
        stopDevice(dev)
        device = nil
        isRunning = false
        writeDebugLog("[MultitouchManager] Stopped global background multitouch monitoring")
    }
    
    // 双指手势生命周期状态机与去抖动（Debounce）缓冲
    private var inGesture = false
    private var consecutiveFramesBelowThreshold = 0
    private let endGestureFrameThreshold = 6 // 连续 6 帧（约 50-60ms）活动手指小于 2 根才真正判定手势结束
    
    private func handleContacts(_ contactsPtr: UnsafeMutablePointer<MTContact>?, count: Int) {
        guard let contacts = contactsPtr else { return }
        
        var activePoints: [Int: CGPoint] = [:]
        for i in 0..<count {
            let contact = contacts[i]
            // 印出所有手指的 state 信息用于诊断
            writeDebugLog("[MultitouchManager] Contact[\(i)]: ID = \(contact.identifier), state = \(contact.state), pos = (\(contact.normalized.pos.x), \(contact.normalized.pos.y))")
            
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
                let x = CGFloat(contact.normalized.pos.x)
                let y = CGFloat(contact.normalized.pos.y)
                activePoints[id] = CGPoint(x: x, y: y)
            }
        }
        
        writeDebugLog("[MultitouchManager] handleContacts: activePoints count = \(activePoints.count), inGesture = \(inGesture), consecutiveFramesBelowThreshold = \(consecutiveFramesBelowThreshold)")
        
        // 当触控板上有且至少有 2 根手指活动时，激活或更新旋钮手势
        if activePoints.count >= 2 {
            consecutiveFramesBelowThreshold = 0 // 只要稳定探测到双指，就重置去抖计数器
            if !inGesture {
                inGesture = true
                writeDebugLog("[MultitouchManager] Gesture trigger: onMultitouchBegan with points = \(activePoints)")
                DispatchQueue.main.async {
                    self.delegate?.onMultitouchBegan(points: activePoints)
                }
            } else {
                writeDebugLog("[MultitouchManager] Gesture trigger: onMultitouchMoved with points = \(activePoints)")
                DispatchQueue.main.async {
                    self.delegate?.onMultitouchMoved(points: activePoints)
                }
            }
        } else if activePoints.count == 0 {
            // 🌟 核心改进：当触碰点数为 0 时，说明手指完全抬起，不存在防抖抖动需要，立即无延迟终止手势！
            // 这也避免了由于触碰点归零后硬件不再发送 Callback 帧，导致防抖计数器卡在半途无法触发 End 的 Bug
            if inGesture {
                inGesture = false
                consecutiveFramesBelowThreshold = 0
                writeDebugLog("[MultitouchManager] Gesture trigger: onMultitouchEnded (Immediate - 0 fingers)")
                DispatchQueue.main.async {
                    self.delegate?.onMultitouchEnded()
                }
            }
        } else {
            // 如果活动手指为 1 根，且之前处于旋钮状态中，则进行去抖动判定，防止接触面积微调导致闪烁
            if inGesture {
                consecutiveFramesBelowThreshold += 1
                writeDebugLog("[MultitouchManager] Jitter Warning: Active count \(activePoints.count) is below 2. Consecutive frames below threshold: \(consecutiveFramesBelowThreshold)/\(endGestureFrameThreshold)")
                
                if consecutiveFramesBelowThreshold >= endGestureFrameThreshold {
                    inGesture = false
                    consecutiveFramesBelowThreshold = 0
                    writeDebugLog("[MultitouchManager] Gesture trigger: onMultitouchEnded (Debounced - 1 finger)")
                    DispatchQueue.main.async {
                        self.delegate?.onMultitouchEnded()
                    }
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
