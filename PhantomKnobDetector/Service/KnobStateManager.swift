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
    private var fixedCenter: CGPoint?
    private var fingerIdx1: Int?
    private var fingerIdx2: Int?
    
    private var currentZoneIndex: Int = 0
    private var activeScaleConfig: ScaleConfig = .fixed(1.0)
    private var lastResolvedBaseScale: Double = 1.0
    private var previousKeysState: Set<CGKeyCode> = []

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
        
        previousKeysState.removeAll()

        // 立即清除并废止冷却倒计时，防止在检测期间状态突变
        coolingTimer?.invalidate()
        coolingTimer = nil

        // 如果前一次是在冷却状态，重置回激活状态准备新一轮手势判定
        if state.isCooling {
            transition(to: .activated)
        }

        // 1. 探测目标元素
        let detectedTarget = targetDetector.detectTargetAtMousePosition()

        // 2. 创建 DetectedTarget（无 AX 元素时用当前 app 信息填充）
        let target = detectedTarget ?? DetectedTarget(
            bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
            axRole: "unknown",
            identifier: nil,
            displayName: "",
            element: nil
        )
        currentTarget = target

        // 3. 查规则库（未命中则自动探测）
        let rule = RuleLibrary.shared.lookup(for: target.ruleKey)

        // 4. 创建 InputTranslator
        let translator = makeTranslator(for: target, rule: rule)
        currentTranslator = translator
 
        // 解析并缓存 ScaleConfig 与状态变量重置
        let resolvedScaleConfig: ScaleConfig
        if let ruleScaleConfig = rule?.scaleConfig {
            switch ruleScaleConfig {
            case .fixed(let val):
                if val == 1.0 {
                    resolvedScaleConfig = AppSettings.shared.activeScheme == "linear"
                        ? .linear(AppSettings.shared.linear)
                        : .zones(AppSettings.shared.fixed.zones)
                } else {
                    resolvedScaleConfig = .fixed(val)
                }
            default:
                resolvedScaleConfig = ruleScaleConfig
            }
        } else {
            resolvedScaleConfig = AppSettings.shared.activeScheme == "linear"
                ? .linear(AppSettings.shared.linear)
                : .zones(AppSettings.shared.fixed.zones)
        }
        self.activeScaleConfig = resolvedScaleConfig
        self.currentZoneIndex = 0
        self.lastResolvedBaseScale = 1.0

        // 5. 缓存鼠标位置，不直接进入 knobing
        let mouseLoc = NSEvent.mouseLocation
        initialTouchPosition = mouseLoc
        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        initialTouchPositionCarbon = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)

        let scaledPoints = scaleCoordinates(points)
        let (knobCore, idx1, idx2) = KnobAlgorithm().calKnob(scaledPoints)
        if knobCore.isValid {
            self.fixedCenter = knobCore.center
            self.fingerIdx1 = idx1
            self.fingerIdx2 = idx2
            self.previousAngle = knobCore.angle
        }
        gestureClassifier.processTouchesBegan(points: points)
    }

    func onMultitouchMoved(points: [Int: CGPoint]) {
        guard state != .inactive, let translator = currentTranslator else { return }

        let scaledPoints = scaleCoordinates(points)
        guard let currentAngle = calculateRawAngle(points: scaledPoints) else { return }

        let currentTouchCount = scaledPoints.count
        // 单指重新升级回双指时，重新缓存双指的 ID 对应关系以备下一次抬指匹配
        if currentTouchCount >= 2 {
            let (_, idx1, idx2) = KnobAlgorithm().calKnob(scaledPoints)
            self.fingerIdx1 = idx1
            self.fingerIdx2 = idx2
        }

        // 🌟 进行手势判定是否升级为 knob
        let mode = gestureClassifier.processTouchesMoved(points: points)
        if mode == .knob && !state.isKnobing {
            if let target = currentTarget {
                transition(to: .knobing(target: target))
                if let mouseLoc = initialTouchPosition {
                    overlayController.show(
                        at: mouseLoc,
                        targetName: target.displayName.isEmpty ? nil : target.displayName,
                        displayValue: translator.displayValue,
                        scale: self.lastResolvedBaseScale
                    )
                }
            }
        }

        if state.isKnobing {
            if let lockPos = initialTouchPositionCarbon {
                CGWarpMouseCursorPosition(lockPos)
            }

            // 1. Option Modifier and Edge-Triggered Polling
            let optionDown = CGEventSource.keyState(.combinedSessionState, key: 58) || CGEventSource.keyState(.combinedSessionState, key: 61)
            var newlyPressed: Set<CGKeyCode> = []
            if optionDown && AppSettings.shared.enableKeyboardNumberMultiplier {
                let keysToPoll: [CGKeyCode] = [
                    18, // 1
                    19, 20, 21, 23, 22, 26, 28, 25, // 2-9
                    126, 125, 123, 124 // Up, Down, Left, Right
                ]
                var currentPressed: Set<CGKeyCode> = []
                for keyCode in keysToPoll {
                    if CGEventSource.keyState(.combinedSessionState, key: keyCode) {
                        currentPressed.insert(keyCode)
                    }
                }
                newlyPressed = currentPressed.subtracting(previousKeysState)
                previousKeysState = currentPressed
            } else {
                previousKeysState.removeAll()
            }

            // 2. Resolve default base scale dynamically from radius
            var resolvedZoneIndex = currentZoneIndex
            let defaultBaseScale: Double?
            
            let radius = calculateRawRadius(points: scaledPoints)
            switch activeScaleConfig {
            case .fixed(let val):
                defaultBaseScale = val
                resolvedZoneIndex = 0
            case .zones(let zones):
                defaultBaseScale = ScaleResolver.resolveHysteresis(radius: radius, zones: zones, currentZoneIndex: &resolvedZoneIndex)
            case .linear(let config):
                defaultBaseScale = ScaleResolver.resolveLinear(radius: radius, config: config)
                resolvedZoneIndex = 0
            }
            
            if resolvedZoneIndex != currentZoneIndex {
                currentZoneIndex = resolvedZoneIndex
            }
            
            // Apply override if available
            var baseScale: Double?
            if let defaultScale = defaultBaseScale {
                if let target = currentTarget {
                    let key = persistentKey(for: target, zoneIndex: currentZoneIndex)
                    if let overrideValue = UserDefaults.standard.object(forKey: key) as? Double {
                        baseScale = overrideValue
                    } else {
                        baseScale = defaultScale
                    }
                } else {
                    baseScale = defaultScale
                }
            } else {
                baseScale = nil
            }
            
            // Handle edge-triggered key overrides and modifications
            if let target = currentTarget, let currentVal = baseScale {
                let key = persistentKey(for: target, zoneIndex: currentZoneIndex)
                var updatedVal: Double? = nil
                
                if newlyPressed.contains(18) {
                    // Option + 1 -> Reset to safe value 1.0
                    updatedVal = 1.0
                } else if let num = getNumberPressed(from: newlyPressed) {
                    // Option + 2-9
                    updatedVal = Double(num)
                } else if let delta = getArrowDelta(from: newlyPressed) {
                    // Option + Arrow keys
                    let rawNewVal = currentVal + delta
                    updatedVal = max(0.1, (rawNewVal * 10).rounded() / 10)
                }
                
                if let nextVal = updatedVal {
                    UserDefaults.standard.set(nextVal, forKey: key)
                    baseScale = nextVal
                }
            }
            
            if let resolved = baseScale {
                self.lastResolvedBaseScale = resolved
            }

            // 3. 检查死区判定
            guard let activeBaseScale = baseScale else {
                // radius < minRadius, 进入死区：丢弃本帧变化，Overlay UI 变灰
                let displayVal = translator.displayValue
                overlayController.update(angle: currentAngle, displayValue: displayVal, isDeadzone: true, scale: self.lastResolvedBaseScale)
                self.currentAngle = currentAngle
                previousAngle = currentAngle
                return
            }

            // 4. 读取系统面板灵敏度并合成最终步长倍率
            let globalSens = UserDefaults.standard.object(forKey: "globalSensitivity") as? Double ?? 1.0
            let settingsSensitivity: Double
            if let target = currentTarget {
                switch target.axRole {
                case "AXSlider":
                    settingsSensitivity = UserDefaults.standard.object(forKey: "sliderSensitivity") as? Double ?? globalSens
                case "AXProgressIndicator":
                    settingsSensitivity = UserDefaults.standard.object(forKey: "progressSensitivity") as? Double ?? globalSens
                default:
                    settingsSensitivity = globalSens
                }
            } else {
                settingsSensitivity = globalSens
            }

            let finalScale = activeBaseScale * settingsSensitivity
            translator.scale = finalScale

            // 5. 注入翻译事件
            let knobState = KnobState(
                current: KnobCore(angle: currentAngle),
                previous: KnobCore(angle: previousAngle)
            )
            let deltaAngle = abs(knobState.deltaAngle)
            let direction: RotationDirection = knobState.deltaAngle >= 0 ? .clockwise : .counterClockwise

            translator.apply(units: deltaAngle, direction: direction)

            let displayVal = translator.displayValue
            overlayController.update(angle: currentAngle, displayValue: displayVal, isDeadzone: false, scale: activeBaseScale)

            self.currentAngle = currentAngle
            previousAngle = currentAngle

            writeDebugLog("[KnobStateManager] applied delta=\(deltaAngle) dir=\(direction) scale=\(finalScale)")
        }
    }

    func onMultitouchEnded() {
        guard state != .inactive else { return }
        previousKeysState.removeAll()
        gestureClassifier.processTouchesEnded()
        initialTouchPositionCarbon = nil

        if state.isKnobing, let target = currentTarget {
            transition(to: .cooling(target: target))
            overlayController.fadeOut { [weak self] in
                self?.startCoolingTimer()
            }
        } else {
            // 🌟 若手指抬起前从未触发过旋钮手势，静默归位激活状态并清除临时变量
            transition(to: .activated)
            currentTarget = nil
            currentTranslator = nil
            fixedCenter = nil
            fingerIdx1 = nil
            fingerIdx2 = nil
        }
    }

    private func persistentKey(for target: DetectedTarget, zoneIndex: Int) -> String {
        let bundleID = target.bundleID
        let axRole = target.axRole
        let identifier = target.identifier ?? ""
        let displayName = target.displayName
        return "knob_scale_override_\(bundleID)_\(axRole)_\(identifier)_\(displayName)_zone_\(zoneIndex)"
    }

    private func getNumberPressed(from pressed: Set<CGKeyCode>) -> Int? {
        let keyMapping: [CGKeyCode: Int] = [
            19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
        ]
        for (k, v) in keyMapping {
            if pressed.contains(k) { return v }
        }
        return nil
    }

    private func getArrowDelta(from pressed: Set<CGKeyCode>) -> Double? {
        if pressed.contains(126) { return 1.0 }   // Up
        if pressed.contains(125) { return -1.0 }  // Down
        if pressed.contains(124) { return 0.1 }   // Right
        if pressed.contains(123) { return -0.1 }  // Left
        return nil
    }

    // MARK: - Helper Methods
    
    private func calculateRawAngle(points: [Int: CGPoint]) -> Double? {
        if points.count >= 2 {
            let (knobCore, _, _) = KnobAlgorithm().calKnob(points)
            return knobCore.isValid ? knobCore.angle : nil
        } else if points.count == 1,
                  let fixedCenter = self.fixedCenter,
                  let fingerIdx1 = self.fingerIdx1,
                  let fingerIdx2 = self.fingerIdx2,
                  let remainId = points.keys.first,
                  let remainPoint = points[remainId] {
            
            let dx: CGFloat
            let dy: CGFloat
            // 根据剩余手指硬件 ID，决定矢量方向，抵消 180 度偏置
            if remainId == fingerIdx1 {
                dx = remainPoint.x - fixedCenter.x
                dy = remainPoint.y - fixedCenter.y
            } else if remainId == fingerIdx2 {
                dx = fixedCenter.x - remainPoint.x
                dy = fixedCenter.y - remainPoint.y
            } else {
                dx = remainPoint.x - fixedCenter.x
                dy = remainPoint.y - fixedCenter.y
            }
            return atan2(dy, dx) * 180 / .pi
        }
        return nil
    }

    private func scaleCoordinates(_ points: [Int: CGPoint]) -> [Int: CGPoint] {
        var scaled: [Int: CGPoint] = [:]
        let mouseLocation = NSEvent.mouseLocation
        for (id, pt) in points {
            scaled[id] = CGPoint(
                x: mouseLocation.x + pt.x,
                y: mouseLocation.y + pt.y
            )
        }
        return scaled
    }

    private func calculateRawRadius(points: [Int: CGPoint]) -> Double {
        if points.count >= 2 {
            let (knobCore, _, _) = KnobAlgorithm().calKnob(points)
            return knobCore.isValid ? knobCore.radius : 0.0
        } else if points.count == 1,
                  let fixedCenter = self.fixedCenter,
                  let remainId = points.keys.first,
                  let remainPoint = points[remainId] {
            let dx = remainPoint.x - fixedCenter.x
            let dy = remainPoint.y - fixedCenter.y
            return sqrt(dx * dx + dy * dy)
        }
        return 0.0
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
