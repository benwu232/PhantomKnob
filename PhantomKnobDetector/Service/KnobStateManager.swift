import Foundation
import AppKit
import Combine

class KnobStateManager: ObservableObject, GlobalTouchDelegate, MultitouchEventDelegate {
    @Published private(set) var state: KnobGlobalState = .inactive
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var displayValue: String = ""
    
    private let targetDetector: TargetDetector
    private let gestureClassifier: GestureClassifier
    private let overlayController: OverlayController
    private let statusBarController: StatusBarController
    private let touchHandler: GlobalTouchHandler
    private let sensitivityConfig: SensitivityConfig
    
    private var currentTarget: ControlTarget?
    private var initialTouchPosition: CGPoint?
    private var initialTouchPositionCarbon: CGPoint? // 锁定鼠标的 Carbon 坐标 (左上角原点)
    private var previousAngle: Double = 0
    private var isOptionHoldActive = false
    private var coolingTimer: Timer?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        targetDetector: TargetDetector,
        gestureClassifier: GestureClassifier,
        overlayController: OverlayController,
        statusBarController: StatusBarController,
        touchHandler: GlobalTouchHandler,
        sensitivityConfig: SensitivityConfig = SensitivityConfig()
    ) {
        self.targetDetector = targetDetector
        self.gestureClassifier = gestureClassifier
        self.overlayController = overlayController
        self.statusBarController = statusBarController
        self.touchHandler = touchHandler
        self.sensitivityConfig = sensitivityConfig
        
        setupBindings()
    }
    
    private func setupBindings() {
        touchHandler.delegate = self
        
        statusBarController.onToggleHotkey = { [weak self] in
            self?.toggleMode()
        }
        
        NotificationCenter.default.publisher(
            for: NSWorkspace.didActivateApplicationNotification
        )
        .sink { [weak self] _ in
            self?.handleAppSwitch()
        }
        .store(in: &cancellables)
    }
    
    func start() {
        statusBarController.updateState(.inactive)
        touchHandler.startMonitoring()
        
        // 绑定 MultitouchManager 代理
        MultitouchManager.shared.delegate = self
    }
    
    func stop() {
        touchHandler.stopMonitoring()
        MultitouchManager.shared.stop()
        overlayController.hide()
    }
    
    func toggleMode() {
        writeDebugLog("[KnobStateManager] toggleMode() called, current state: \(state)")
        if case .inactive = state {
            let isTrusted = AXIsProcessTrusted()
            guard isTrusted else {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
                return
            }
            writeDebugLog("[KnobStateManager] Transitioning to activated")
            transition(to: .activated)
            
            // 启动后台多点触控捕获
            MultitouchManager.shared.start()
        } else {
            writeDebugLog("[KnobStateManager] Transitioning to inactive")
            transition(to: .inactive)
            
            // 停止后台多点触控捕获
            MultitouchManager.shared.stop()
            
            currentTarget = nil
            overlayController.hide()
            targetDetector.clearCache()
        }
    }
    
    private func transition(to newState: KnobGlobalState) {
        state = newState
        let targetName = currentTarget?.displayName
        statusBarController.updateState(newState, targetName: targetName)
    }
    
    private func handleAppSwitch() {
        guard state != .inactive else { return }
        transition(to: .activated)
        currentTarget = nil
        overlayController.hide()
        targetDetector.clearCache()
    }
    
    // MARK: - GlobalTouchDelegate
    
    func onGlobalModifierOptionChanged(isPressed: Bool) {
        // Option Hold 模式支持
        if isPressed {
            if !isOptionHoldActive && state == .inactive {
                isOptionHoldActive = true
                writeDebugLog("[KnobStateManager] Option key held, starting background multitouch capture")
                transition(to: .activated)
                MultitouchManager.shared.start()
            }
        } else {
            if isOptionHoldActive {
                isOptionHoldActive = false
                writeDebugLog("[KnobStateManager] Option key released, stopping background multitouch capture")
                transition(to: .inactive)
                MultitouchManager.shared.stop()
                overlayController.hide()
                currentTarget = nil
            }
        }
    }
    
    func onGlobalScroll(phase: NSEvent.Phase, deltaX: CGFloat, deltaY: CGFloat) {
        // 保留系统底层原生滚轮调节的兜底支持
    }
    
    // MARK: - MultitouchEventDelegate (硬件绝对坐标多指捕获)
    
    func onMultitouchBegan(points: [Int: CGPoint]) {
        writeDebugLog("[KnobStateManager] onMultitouchBegan: points count = \(points.count), state = \(state)")
        guard state != .inactive else { return }
        
        // 尝试定位鼠标当前悬停的目标可调整滑块，若失败则使用 GenericControlTarget 兜底，保证必有 Target
        let target = (targetDetector.detectTargetAtMousePosition() as ControlTarget?) ?? GenericControlTarget()
        writeDebugLog("[KnobStateManager] Target obtained: \(target.displayName)")
        currentTarget = target
        
        let mouseLoc = NSEvent.mouseLocation
        initialTouchPosition = mouseLoc
        
        // 转换并缓存 Carbon 坐标以便于进行鼠标 Warp 锁定
        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        initialTouchPositionCarbon = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)
        
        // 缩放物理坐标以吻合屏幕夹角向量变化
        let scaledPoints = scaleCoordinates(points)
        gestureClassifier.processTouchesBegan(points: scaledPoints)
        previousAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)
        
        // 立即进入 knobing 状态并展示 Overlay 窗口，去除 5.0 度角阈值限制！
        transition(to: .knobing(target: target))
        
        let displayVal = (target as? AccessibilityTarget)?.displayValue() ?? String(format: "%.0f%%", target.value)
        overlayController.show(
            at: mouseLoc,
            targetName: target.displayName,
            displayValue: displayVal
        )
    }
    
    func onMultitouchMoved(points: [Int: CGPoint]) {
        writeDebugLog("[KnobStateManager] onMultitouchMoved: points count = \(points.count), state = \(state), currentTarget = \(currentTarget?.displayName ?? "nil")")
        guard state != .inactive, let target = currentTarget else { return }
        
        let scaledPoints = scaleCoordinates(points)
        
        // 去除 pan/knob 分类器限制，直接按旋钮模式处理，以实现最快且 100% 成功的交互响应
        let currentAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)
        
        if state.isKnobing {
            // 关键修复：当旋钮处于激活控制状态时，锁定鼠标光标到初始位置，防止其漂移出控件范围失效
            if let lockPos = initialTouchPositionCarbon {
                CGWarpMouseCursorPosition(lockPos)
            }
            
            let knobState = KnobState(
                current: KnobCore(angle: currentAngle),
                previous: KnobCore(angle: previousAngle)
            )
            
            // 计算双指单帧旋转的角度差值
            let deltaRotation = knobState.deltaAngle
            
            // 在 HUD 视觉层及底层控制层同步刷新数据
            if target is GenericControlTarget {
                // 通用兜底控制：利用高精度滚轮投递合成，使非 AX 组件依然可以随着手势滚动
                let range = abs(target.maxValue - target.minValue)
                let scrollScale: Double = (range <= 1.0) ? 1.0 : ((range <= 100.0) ? 2.5 : 8.0)
                let scrollDelta = deltaRotation * scrollScale
                
                synthesizeScrollWheelEvent(deltaY: CGFloat(scrollDelta))
                
                _ = target.applyDelta(deltaRotation)
                displayValue = String(format: "%.0f%%", target.value)
            } else {
                // 极简精准控制：直接通过 Accessibility API 写入属性，达到完美的 1° 对应 1% 精准调节，绕过系统复杂的滚轮加速度，杜绝调整吃力问题
                let newValue = target.applyDelta(deltaRotation)
                displayValue = (target as? AccessibilityTarget)?.displayValue() ?? "\(Int(newValue))"
            }
            
            overlayController.update(angle: currentAngle, displayValue: displayValue)
            
            self.currentAngle = currentAngle
            previousAngle = currentAngle
        }
    }
    
    func onMultitouchEnded() {
        writeDebugLog("[KnobStateManager] onMultitouchEnded")
        guard state != .inactive else { return }
        gestureClassifier.processTouchesEnded()
        
        initialTouchPositionCarbon = nil // 清除鼠标锁定坐标
        
        if state.isKnobing, let target = currentTarget {
            transition(to: .cooling(target: target))
            overlayController.fadeOut { [weak self] in
                self?.startCoolingTimer()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func scaleCoordinates(_ points: [Int: CGPoint]) -> [Int: CGPoint] {
        var scaled: [Int: CGPoint] = [:]
        let mouseLocation = NSEvent.mouseLocation
        for (id, pt) in points {
            scaled[id] = CGPoint(
                x: mouseLocation.x + pt.x * 100,
                y: mouseLocation.y + pt.y * 100
            )
        }
        return scaled
    }
    
    private func synthesizeScrollWheelEvent(deltaX: CGFloat = 0.0, deltaY: CGFloat = 0.0) {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY), // 整数部分作为兼容备用
            wheel2: Int32(deltaX),
            wheel3: 0
        )
        // 关键修复：写入高精度浮点数 Delta 属性，使慢速微调旋转时依然能流畅响应
        scrollEvent?.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: Double(deltaY))
        scrollEvent?.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: Double(deltaX))
        scrollEvent?.post(tap: .cghidEventTap)
    }
    
    private func startCoolingTimer() {
        coolingTimer?.invalidate()
        coolingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.state.isCooling {
                self.transition(to: .activated)
                self.currentTarget = nil
            }
        }
    }
}

// [DEBUG-LOG-HARNESS]
func writeDebugLog(_ message: String) {
    NSLog("[DEBUG-LOG-HARNESS] \(message)")
    let logPath = "/Users/wb/work/phantom_knob_mac/debug.log"
    let timestamp = Date().description
    let logLine = "[\(timestamp)] \(message)\n"
    if let data = logLine.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }
}
