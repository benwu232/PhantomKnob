import Foundation
import AppKit
import Combine

class KnobStateManager: ObservableObject, GlobalTouchDelegate {
    @Published private(set) var state: KnobGlobalState = .inactive
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var displayValue: String = ""
    
    private let targetDetector: TargetDetector
    private let gestureClassifier: GestureClassifier
    private let overlayController: OverlayController
    private let statusBarController: StatusBarController
    private let touchHandler: GlobalTouchHandler
    private let sensitivityConfig: SensitivityConfig
    
    private var coolingTimer: Timer?
    private var currentTarget: ControlTarget?
    private var initialTouchPosition: CGPoint?
    private var previousAngle: Double = 0
    
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
    }
    
    func stop() {
        touchHandler.stopMonitoring()
        overlayController.hide()
    }
    
    func toggleMode() {
        writeDebugLog("[KnobStateManager] toggleMode() called, current state: \(state)")
        NSLog("[KnobStateManager] toggleMode() called, current state: \(state)")
        if case .inactive = state {
            let isTrusted = AXIsProcessTrusted()
            writeDebugLog("[KnobStateManager] AXIsProcessTrusted checked: \(isTrusted)")
            NSLog("[KnobStateManager] AXIsProcessTrusted: \(isTrusted)")
            guard isTrusted else {
                writeDebugLog("[KnobStateManager] Accessibility not granted, cannot activate")
                NSLog("[KnobStateManager] Accessibility not granted, cannot activate")
                // 弹出 macOS 系统级辅助功能权限请求框，引导用户点击一键跳转至“系统设置”对应页面
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
                return
            }
            writeDebugLog("[KnobStateManager] Transitioning to activated")
            NSLog("[KnobStateManager] Transitioning to activated")
            transition(to: .activated)
        } else {
            writeDebugLog("[KnobStateManager] Transitioning to inactive")
            NSLog("[KnobStateManager] Transitioning to inactive")
            transition(to: .inactive)
            currentTarget = nil
            overlayController.hide()
            targetDetector.clearCache()
        }
    }
    
    private func transition(to newState: KnobGlobalState) {
        NSLog("[KnobStateManager] transition(to: \(newState))")
        state = newState
        let targetName = currentTarget?.displayName
        statusBarController.updateState(newState, targetName: targetName)
        NSLog("[KnobStateManager] State updated, calling statusBarController.updateState")
    }
    
    private func handleAppSwitch() {
        guard state != .inactive else { return }
        transition(to: .activated)
        currentTarget = nil
        overlayController.hide()
        targetDetector.clearCache()
    }
    
    // MARK: - GlobalTouchDelegate
    
    func onGlobalTouchesBegan(_ touches: Set<NSTouch>) {
        guard state != .inactive else { return }
        
        if let target = targetDetector.detectTargetAtMousePosition() {
            currentTarget = target
            initialTouchPosition = NSEvent.mouseLocation
            let points = extractPoints(from: touches)
            gestureClassifier.processTouchesBegan(points: points)
            previousAngle = gestureClassifier.getCurrentAngle(points: points)
        } else {
            gestureClassifier.forcePassthrough()
        }
    }
    
    func onGlobalTouchesMoved(_ touches: Set<NSTouch>) {
        guard state != .inactive, let target = currentTarget else { return }
        
        let points = extractPoints(from: touches)
        let mode = gestureClassifier.processTouchesMoved(points: points)
        
        switch mode {
        case .knob:
            let currentAngle = gestureClassifier.getCurrentAngle(points: points)
            
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
                
                let newValue = target.applyDelta(knobState.deltaAngle)
                displayValue = formatDisplayValue(newValue, min: target.minValue, max: target.maxValue)
                overlayController.update(angle: currentAngle, displayValue: displayValue)
                self.currentAngle = currentAngle
                previousAngle = currentAngle
            }
            
        case .pan, .passthrough:
            break
        }
    }
    
    func onGlobalTouchesEnded(_ touches: Set<NSTouch>) {
        guard state != .inactive else { return }
        
        gestureClassifier.processTouchesEnded()
        
        if state.isKnobing, let target = currentTarget {
            transition(to: .cooling(target: target))
            overlayController.fadeOut { [weak self] in
                self?.startCoolingTimer()
            }
        }
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
    
    private func extractPoints(from touches: Set<NSTouch>) -> [Int: CGPoint] {
        var points: [Int: CGPoint] = [:]
        let mouseLocation = NSEvent.mouseLocation
        
        for touch in touches {
            let normalizedPos = touch.normalizedPosition
            let point = CGPoint(
                x: mouseLocation.x + normalizedPos.x * 100,
                y: mouseLocation.y + normalizedPos.y * 100
            )
            // Use touch.identity for a stable key across events — the same
            // physical finger always gets the same ID, so fingerIdx1 = min(id1,id2)
            // in KnobAlgorithm always refers to the same finger and the angle
            // vector never flips direction mid-gesture.
            let stableId = ObjectIdentifier(touch.identity).hashValue
            points[stableId] = point
        }
        
        return points
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
