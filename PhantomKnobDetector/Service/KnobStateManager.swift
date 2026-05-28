// PhantomKnobDetector/Service/KnobStateManager.swift
import Foundation
import AppKit
import Combine
import ApplicationServices

class KnobStateManager: ObservableObject, GlobalTouchDelegate, MultitouchEventDelegate {
    @Published private(set) var state: KnobGlobalState = .inactive
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var displayValue: String = ""

    private let targetDetector: TargetDetector
    private let gestureClassifier: GestureClassifier
    private let overlayController: OverlayController
    private let statusBarController: StatusBarController
    private let touchHandler: GlobalTouchHandler
    private var currentTarget: DetectedTarget?
    private var currentTranslator: InputTranslator?
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
            currentTranslator = nil
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
        currentTranslator = nil
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
                currentTranslator = nil
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

        // 1. 探测目标元素
        let detectedTarget = targetDetector.detectTargetAtMousePosition()

        // 2. 查规则库（未命中则自动探测）
        let rule: ControlRule?
        if let target = detectedTarget {
            rule = RuleLibrary.shared.lookup(for: target.ruleKey)
        } else {
            rule = nil
        }

        // 3. 创建兜底 DetectedTarget（无 AX 元素时用当前 app 信息填充）
        let target = detectedTarget ?? DetectedTarget(
            bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
            axRole: "unknown",
            identifier: nil,
            displayName: "",
            element: nil
        )
        currentTarget = target

        // 4. 创建 InputTranslator
        let translator = makeTranslator(for: target, rule: rule)
        currentTranslator = translator

        // 5. 缓存鼠标位置，进入 knobing
        let mouseLoc = NSEvent.mouseLocation
        initialTouchPosition = mouseLoc
        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        initialTouchPositionCarbon = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)

        let scaledPoints = scaleCoordinates(points)
        gestureClassifier.processTouchesBegan(points: scaledPoints)
        previousAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)

        transition(to: .knobing(target: target))

        overlayController.show(
            at: mouseLoc,
            targetName: target.displayName.isEmpty ? nil : target.displayName,
            displayValue: translator.displayValue
        )
    }

    func onMultitouchMoved(points: [Int: CGPoint]) {
        guard state != .inactive, let translator = currentTranslator else { return }

        let scaledPoints = scaleCoordinates(points)
        let currentAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)

        if state.isKnobing {
            if let lockPos = initialTouchPositionCarbon {
                CGWarpMouseCursorPosition(lockPos)
            }

            let knobState = KnobState(
                current: KnobCore(angle: currentAngle),
                previous: KnobCore(angle: previousAngle)
            )
            let deltaAngle = abs(knobState.deltaAngle)
            let direction: RotationDirection = knobState.deltaAngle >= 0 ? .clockwise : .counterClockwise

            translator.apply(units: deltaAngle, direction: direction)

            let displayVal = translator.displayValue
            overlayController.update(angle: currentAngle, displayValue: displayVal)

            self.currentAngle = currentAngle
            previousAngle = currentAngle

            writeDebugLog("[KnobStateManager] applied delta=\(deltaAngle) dir=\(direction)")
        }
    }

    func onMultitouchEnded() {
        guard state != .inactive else { return }
        gestureClassifier.processTouchesEnded()
        initialTouchPositionCarbon = nil

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

    private func startCoolingTimer() {
        coolingTimer?.invalidate()
        coolingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.state.isCooling {
                self.transition(to: .activated)
                self.currentTarget = nil
                self.currentTranslator = nil
            }
        }
    }

    // MARK: - Translator Factory

    private func makeTranslator(for target: DetectedTarget, rule: ControlRule?) -> InputTranslator {
        let translation = rule?.translation ?? autoDetectTranslation(for: target)
        let scale = rule?.scaleConfig.resolve() ?? 1.0

        switch translation {
        case .axWrite:
            guard let element = target.element,
                  let minV = TargetDetector.getDouble(from: element, attribute: kAXMinValueAttribute),
                  let maxV = TargetDetector.getDouble(from: element, attribute: kAXMaxValueAttribute)
            else {
                // AX 元素不可用，降级到滚轮
                return ScrollWheelTranslator(axis: .vertical, scale: scale)
            }
            return AXWriteTranslator(element: element, minValue: minV, maxValue: maxV, scale: scale)

        case .scrollWheelVertical:
            return ScrollWheelTranslator(axis: .vertical, scale: scale)

        case .scrollWheelHorizontal:
            return ScrollWheelTranslator(axis: .horizontal, scale: scale)

        case .arrowKeyUpDown:
            return ArrowKeyTranslator(axis: .upDown, scale: scale)

        case .arrowKeyLeftRight:
            return ArrowKeyTranslator(axis: .leftRight, scale: scale)

        case .swipeVertical:
            // 使用滚轮模拟，直到专用 swipe 实现完成
            return ScrollWheelTranslator(axis: .vertical, scale: scale)

        case .swipeHorizontal:
            return ScrollWheelTranslator(axis: .horizontal, scale: scale)
        }
    }

    private func autoDetectTranslation(for target: DetectedTarget) -> InputTranslation {
        guard let element = target.element else { return .scrollWheelVertical }
        return TargetDetector.autoDetectTranslation(for: element)
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
