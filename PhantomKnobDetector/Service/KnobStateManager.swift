import Foundation
import AppKit
import Combine

class KnobStateManager: ObservableObject, GlobalTouchDelegate, GestureOverlayDelegate {
    @Published private(set) var state: KnobGlobalState = .inactive
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var displayValue: String = ""
    
    private let targetDetector: TargetDetector
    private let gestureClassifier: GestureClassifier
    private let overlayController: OverlayController
    private let statusBarController: StatusBarController
    private let touchHandler: GlobalTouchHandler
    private let sensitivityConfig: SensitivityConfig
    
    // 新增合规全屏手势遮罩管理器
    private var gestureOverlayController: GestureOverlayController?
    private var currentTarget: ControlTarget?
    private var initialTouchPosition: CGPoint?
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
        
        // 初始化手势面板并挂载代理
        let overlay = GestureOverlayController()
        overlay.delegate = self
        self.gestureOverlayController = overlay
    }
    
    func stop() {
        touchHandler.stopMonitoring()
        gestureOverlayController?.hide()
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
            gestureOverlayController?.show() // 开启透明拦截窗口
        } else {
            writeDebugLog("[KnobStateManager] Transitioning to inactive")
            transition(to: .inactive)
            gestureOverlayController?.hide() // 彻底注销并隐藏透明窗口
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
        // 如果用户在设置中勾选了 Option Hold 模式支持
        if isPressed {
            if !isOptionHoldActive && state == .inactive {
                isOptionHoldActive = true
                writeDebugLog("[KnobStateManager] Option key held, showing overlay panel")
                transition(to: .activated)
                gestureOverlayController?.show()
            }
        } else {
            if isOptionHoldActive {
                isOptionHoldActive = false
                writeDebugLog("[KnobStateManager] Option key released, destroying overlay panel")
                transition(to: .inactive)
                gestureOverlayController?.hide()
                overlayController.hide()
                currentTarget = nil
            }
        }
    }
    
    func onGlobalScroll(phase: NSEvent.Phase, deltaX: CGFloat, deltaY: CGFloat) {
        // 保留系统底层原生滚轮调节的兜底支持，但由于手势会被透明窗口先拦截，此方法平时会自动旁路
    }
    
    // MARK: - GestureOverlayDelegate (物理高精坐标多指捕获)
    
    func onOverlayTouchesBegan(points: [Int: CGPoint]) {
        guard state != .inactive else { return }
        
        // 精准定位目标滑块
        if let target = targetDetector.detectTargetAtMousePosition() {
            writeDebugLog("[KnobStateManager] High-precision Target Captured: \(target.displayName), Role = \(target.controlType)")
            currentTarget = target
            initialTouchPosition = NSEvent.mouseLocation
            
            // 缩放物理坐标以吻合屏幕夹角向量变化
            let scaledPoints = scaleCoordinates(points)
            gestureClassifier.processTouchesBegan(points: scaledPoints)
            previousAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)
        } else {
            gestureClassifier.forcePassthrough()
        }
    }
    
    func onOverlayTouchesMoved(points: [Int: CGPoint]) {
        guard state != .inactive, let target = currentTarget else { return }
        
        let scaledPoints = scaleCoordinates(points)
        let mode = gestureClassifier.processTouchesMoved(points: scaledPoints)
        
        switch mode {
        case .knob:
            let currentAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)
            
            if case .activated = state {
                let deltaAngle = abs(currentAngle - previousAngle)
                
                if let result = state.transitionWithResult(
                    event: .gestureStartedWithTarget(target, angleDelta: deltaAngle)
                ) {
                    transition(to: result.state)
                    
                    if let position = initialTouchPosition {
                        overlayController.show(
                            at: position,
                            targetName: target.displayName,
                            displayValue: (target as? AccessibilityTarget)?.displayValue() ?? "\(Int(target.value))"
                        )
                    }
                }
            }
            
            if state.isKnobing {
                let knobState = KnobState(
                    current: KnobCore(angle: currentAngle),
                    previous: KnobCore(angle: previousAngle)
                )
                
                // 通用滚轮映射 (方案 A)：把角度的差值 deltaAngle 转化为通用 Scroll 滚轮增量
                let deltaRotation = knobState.deltaAngle
                
                // 根据目标控制控件的取值范围，平滑转换为滚轮移动步长
                let range = abs(target.maxValue - target.minValue)
                let scrollScale: Double = (range <= 1.0) ? 1.0 : ((range <= 100.0) ? 2.5 : 8.0)
                let scrollDelta = deltaRotation * scrollScale
                
                // 合成硬件级垂直滚轮事件并全局 Post，实现完美通用适配！
                synthesizeScrollWheelEvent(deltaY: CGFloat(-scrollDelta))
                
                // 在 HUD 视觉层同步刷新角度指针和数值反馈
                let newValue = target.value // 滚轮投递后数值会自动变更，这里从滑块直接读取新值
                displayValue = (target as? AccessibilityTarget)?.displayValue() ?? "\(Int(newValue))"
                overlayController.update(angle: currentAngle, displayValue: displayValue)
                
                self.currentAngle = currentAngle
                previousAngle = currentAngle
            }
            
        case .pan:
            // 如果识别为线性滚动，则实时计算双指移动的线性偏移量，合成为普通滚轮进行物理透传
            if let point1 = scaledPoints.values.first, scaledPoints.count >= 2 {
                let deltaX = CGFloat(point1.x - (initialTouchPosition?.x ?? 0.0)) * 0.05
                let deltaY = CGFloat(point1.y - (initialTouchPosition?.y ?? 0.0)) * 0.05
                synthesizeScrollWheelEvent(deltaX: deltaX, deltaY: deltaY)
            }
            
        case .passthrough:
            break
        }
    }
    
    func onOverlayTouchesEnded() {
        guard state != .inactive else { return }
        gestureClassifier.processTouchesEnded()
        
        if state.isKnobing, let target = currentTarget {
            transition(to: .cooling(target: target))
            overlayController.fadeOut { [weak self] in
                self?.startCoolingTimer()
            }
        }
    }
    
    // 核心难点：鼠标点击与拖动动作的瞬间“智能透传”穿透重发
    func onOverlayClickThrough(event: NSEvent) {
        guard let overlay = gestureOverlayController else { return }
        
        // 1. 瞬间关闭透明手势窗口的事件拦截
        overlay.tempDisableInterception()
        
        // 2. 利用 CGEvent 在 HID 底层重新发布这一物理点击/拖拽事件，使其打在原应用上
        if let cgEvent = event.cgEvent {
            cgEvent.post(tap: .cghidEventTap)
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
            wheel1: Int32(deltaY), // 垂直方向
            wheel2: Int32(deltaX), // 水平方向
            wheel3: 0
        )
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
