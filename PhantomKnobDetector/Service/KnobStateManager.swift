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
        if case .inactive = state {
            guard AXIsProcessTrusted() else { return }
            transition(to: .activated)
        } else {
            transition(to: .inactive)
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
        
        for (index, touch) in touches.enumerated() {
            let normalizedPos = touch.normalizedPosition
            let mouseLocation = NSEvent.mouseLocation
            
            let point = CGPoint(
                x: mouseLocation.x + normalizedPos.x * 100,
                y: mouseLocation.y + normalizedPos.y * 100
            )
            
            points[index] = point
        }
        
        return points
    }
}
