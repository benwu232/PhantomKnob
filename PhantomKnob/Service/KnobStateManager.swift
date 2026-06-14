// PhantomKnob/Service/KnobStateManager.swift
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
    var currentTarget: DetectedTarget?
    private var currentTranslator: InputTranslator?
    private var initialTouchPosition: CGPoint?
    private var initialTouchPositionCarbon: CGPoint? // 锁定鼠标 of Carbon coordinate (top-left origin)
    private var previousAngle: Double = 0
    private var isOptionHoldActive = false
    private var coolingTimer: Timer?
    var fixedCenter: CGPoint?
    var fingerIdx1: Int?
    var fingerIdx2: Int?
    
    var currentZoneIndex: Int = 0
    private var activeScaleConfig: ScaleConfig = .fixed(1.0)
    var lastResolvedBaseScale: Double = 1.0
    private var currentRadius: Double = 0.0
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var isInterceptingGestures = false
    private var wasInactiveBeforePanelShow = false
    
    // Mockable accessibility check for unit testing
    var isProcessTrusted: () -> Bool = { AXIsProcessTrusted() }

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
        setupEventTap()
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
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

        NotificationCenter.default.publisher(
            for: NSNotification.Name("KnobPanelDidShow")
        )
        .sink { [weak self] _ in
            self?.handleKnobPanelDidShow()
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSNotification.Name("KnobPanelDidHide")
        )
        .sink { [weak self] _ in
            self?.handleKnobPanelDidHide()
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSNotification.Name("ControlRuleDidUpdate")
        )
        .sink { [weak self] notification in
            guard let self = self,
                  let updatedRule = notification.userInfo?["rule"] as? ControlRule else { return }
            self.handleRuleHotReload(updatedRule)
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
        if isOptionHoldActive {
            writeDebugLog("[KnobStateManager] Converting temporary Option Hold to persistent activated state")
            isOptionHoldActive = false
            if case .cooling = state {
                transition(to: .activated)
            }
        } else if case .inactive = state {
            let isTrusted = isProcessTrusted()
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

    func transition(to newState: KnobGlobalState) {
        state = newState
        let targetName = currentTarget?.displayName
        statusBarController.updateState(newState, targetName: targetName)
        
        if eventTap == nil {
            setupEventTap()
        }
        
        if let tap = eventTap {
            if newState != .inactive {
                CGEvent.tapEnable(tap: tap, enable: true)
                writeDebugLog("[KnobStateManager] Enabled event tap for state: \(newState)")
            } else {
                CGEvent.tapEnable(tap: tap, enable: false)
                writeDebugLog("[KnobStateManager] Disabled event tap for state: \(newState)")
            }
        }
        
        if case .knobing(let target) = newState, target.axRole == "ControlPanel" {
            ControlPanelViewModel.shared.isGestureActive = true
        } else {
            ControlPanelViewModel.shared.isGestureActive = false
        }
    }

    private func handleAppSwitch() {
        guard state != .inactive else { return }
        transition(to: .activated)
        currentTarget = nil
        currentTranslator = nil
        overlayController.hide()
        targetDetector.clearCache()
    }

    private func handleKnobPanelDidShow() {
        writeDebugLog("[KnobStateManager] handleKnobPanelDidShow() called, current state: \(state)")
        if case .inactive = state {
            wasInactiveBeforePanelShow = true
            toggleMode()
        } else {
            wasInactiveBeforePanelShow = false
        }
    }

    private func handleKnobPanelDidHide() {
        writeDebugLog("[KnobStateManager] handleKnobPanelDidHide() called, current state: \(state), wasInactiveBeforePanelShow: \(wasInactiveBeforePanelShow)")
        if state == .customizing {
            transition(to: wasInactiveBeforePanelShow ? .inactive : .activated)
            wasInactiveBeforePanelShow = false
            return
        }
        if wasInactiveBeforePanelShow {
            if state != .inactive {
                toggleMode()
            }
            wasInactiveBeforePanelShow = false
        }
    }

    private func enterCustomization() {
        guard state != .inactive, let target = currentTarget else { return }
        
        // 结束旋转中的手势行为与 Overlay 样式
        isInterceptingGestures = false
        gestureClassifier.processTouchesEnded()
        initialTouchPositionCarbon = nil
        overlayController.hide()
        
        transition(to: .customizing)
        
        // 弹出定制悬浮面板
        CustomizerHUDWindowController.shared.show(for: target)
    }

    private func handleRuleHotReload(_ rule: ControlRule) {
        guard let target = currentTarget, target.ruleKey == rule.key else { return }
        
        // 1. 重新实例化当前 Translator
        let newTranslator = makeTranslator(for: target, rule: rule, radius: self.currentRadius)
        
        // 保留当前已经累积的步长信息防止跳跃
        newTranslator.scale = currentTranslator?.scale ?? 1.0
        self.currentTranslator = newTranslator
        
        // 2. 重新解析 ScaleConfig
        switch rule.configType {
        case .single:
            if let single = rule.singleConfig {
                self.activeScaleConfig = .fixed(single.unitPerDegree)
            }
        case .double:
            if let double = rule.doubleConfig {
                self.activeScaleConfig = .zones([
                    RadiusZone(minRadius: double.inner.minRadius, maxRadius: double.inner.maxRadius, margin: double.inner.margin, scale: double.inner.unitPerDegree),
                    RadiusZone(minRadius: double.outer.minRadius, maxRadius: double.outer.maxRadius, margin: double.outer.margin, scale: double.outer.unitPerDegree)
                ])
            }
        case .linear:
            if let linear = rule.linearConfig {
                self.activeScaleConfig = .linear(ScaleConfigLinear(minRadius: linear.minRadius, maxRadius: linear.maxRadius, minScale: linear.minScale, maxScale: linear.maxScale))
            }
        }
        
        // 3. 即时刷新 Overlay UI 配色与样式
        if isInterceptingGestures {
            overlayController.show(
                at: initialTouchPosition ?? .zero,
                targetName: target.displayName.isEmpty ? nil : target.displayName,
                scale: lastResolvedBaseScale,
                themeColor: rule.themeColor,
                overlayStyle: rule.overlayStyle,
                rotationStyle: rule.rotationStyle
            )
        }
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
        
        if state == .customizing {
            let scaledPoints = scaleCoordinates(points)
            let radius = calculateRawRadius(points: scaledPoints)
            NotificationCenter.default.post(
                name: NSNotification.Name("CustomizerRadiusDidUpdate"),
                object: nil,
                userInfo: ["radius": radius]
            )
            return
        }
        
        // 立即清除并废止冷却倒计时，防止在检测期间状态突变
        coolingTimer?.invalidate()
        coolingTimer = nil

        if KnobPanelWindowController.shared.isVisible || UserGuideWindowController.shared.isVisible {
            let target = DetectedTarget(
                bundleID: "com.phantomknob.controlpanel",
                axRole: "ControlPanel",
                identifier: nil,
                displayName: "控制面板",
                element: nil
            )
            currentTarget = target
            currentTranslator = ScrollWheelTranslator()
            
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
            isInterceptingGestures = true
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                writeDebugLog("[KnobStateManager] Enabled event tap on begin (ControlPanel mode)")
            }
            return
        }

        // 1. 探测目标元素
        let detectedTarget = targetDetector.detectTargetAtMousePosition()

        // 2. 创建 DetectedTarget（无 AX 元素时用当前 app 信息填充）
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName ?? ""
        let target = detectedTarget ?? DetectedTarget(
            bundleID: frontmostApp?.bundleIdentifier ?? "",
            axRole: "unknown",
            identifier: nil,
            displayName: appName,
            element: nil
        )

        // 检查是否是从冷却状态恢复（如果目标相同，则跳过 5° 的激活阈值）
        var isResuming = false
        if case .cooling(let coolingTarget) = state {
            if target.ruleKey == coolingTarget.ruleKey {
                isResuming = true
            }
        }

        // 如果不是恢复状态，且当前处于冷却状态，重置回激活状态准备新一轮手势判定
        if !isResuming && state.isCooling {
            transition(to: .activated)
        }

        currentTarget = target

        // 检查修饰键激活或当前控件是否可调节
        if isOptionHoldActive || isAdjustable(target: target) {
            isInterceptingGestures = true
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                writeDebugLog("[KnobStateManager] Enabled event tap on begin (adjustable/option hold)")
            }
        } else {
            isInterceptingGestures = false
        }

        // Calculate scaled points and initial radius early to resolve correct translator
        let scaledPoints = scaleCoordinates(points)
        let initialRadius = calculateRawRadius(points: scaledPoints)

        // 3. 查规则库（未命中则自动探测）
        let rule = RuleLibrary.shared.lookup(for: target.ruleKey)

        // 4. 创建 InputTranslator
        let translator = makeTranslator(for: target, rule: rule, radius: initialRadius)
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
            if let r = rule {
                switch r.configType {
                case .single:
                    if let single = r.singleConfig {
                        resolvedScaleConfig = .fixed(single.unitPerDegree)
                    } else {
                        resolvedScaleConfig = .fixed(1.0)
                    }
                case .double:
                    if let d = r.doubleConfig {
                        resolvedScaleConfig = .zones([
                            RadiusZone(minRadius: d.inner.minRadius, maxRadius: d.inner.maxRadius, margin: d.inner.margin, scale: d.inner.unitPerDegree),
                            RadiusZone(minRadius: d.outer.minRadius, maxRadius: d.outer.maxRadius, margin: d.outer.margin, scale: d.outer.unitPerDegree)
                        ])
                    } else {
                        resolvedScaleConfig = .zones(AppSettings.shared.fixed.zones)
                    }
                case .linear:
                    if let l = r.linearConfig {
                        resolvedScaleConfig = .linear(ScaleConfigLinear(minRadius: l.minRadius, maxRadius: l.maxRadius, minScale: l.minScale, maxScale: l.maxScale))
                    } else {
                        resolvedScaleConfig = .linear(AppSettings.shared.linear)
                    }
                }
            } else {
                resolvedScaleConfig = AppSettings.shared.activeScheme == "linear"
                    ? .linear(AppSettings.shared.linear)
                    : .zones(AppSettings.shared.fixed.zones)
            }
        }
        self.activeScaleConfig = resolvedScaleConfig
        
        if !isResuming {
            self.currentZoneIndex = 0
            self.lastResolvedBaseScale = 1.0
        }

        // 5. 缓存鼠标位置，不直接进入 knobing
        let mouseLoc = NSEvent.mouseLocation
        initialTouchPosition = mouseLoc
        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        initialTouchPositionCarbon = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)

        let (knobCore, idx1, idx2) = KnobAlgorithm().calKnob(scaledPoints)
        if knobCore.isValid {
            self.fixedCenter = knobCore.center
            self.fingerIdx1 = idx1
            self.fingerIdx2 = idx2
            self.previousAngle = knobCore.angle
        }
        
        if isResuming {
            transition(to: .knobing(target: target))
            gestureClassifier.forceKnob()
            if let mouseLoc = initialTouchPosition {
                overlayController.show(
                    at: mouseLoc,
                    targetName: target.displayName.isEmpty ? nil : target.displayName,
                    scale: self.lastResolvedBaseScale,
                    themeColor: rule?.themeColor,
                    overlayStyle: rule?.overlayStyle,
                    rotationStyle: rule?.rotationStyle
                )
            }
        } else {
            gestureClassifier.processTouchesBegan(points: points)
        }
    }

    func onMultitouchMoved(points: [Int: CGPoint]) {
        if state == .customizing {
            let scaledPoints = scaleCoordinates(points)
            let radius = calculateRawRadius(points: scaledPoints)
            NotificationCenter.default.post(
                name: NSNotification.Name("CustomizerRadiusDidUpdate"),
                object: nil,
                userInfo: ["radius": radius]
            )
            return
        }
        
        guard state != .inactive, var translator = currentTranslator else { return }

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
                let rule = RuleLibrary.shared.lookup(for: target.ruleKey)
                if let mouseLoc = initialTouchPosition {
                    if target.axRole != "ControlPanel" {
                        overlayController.show(
                            at: mouseLoc,
                            targetName: target.displayName.isEmpty ? nil : target.displayName,
                            scale: self.lastResolvedBaseScale,
                            themeColor: rule?.themeColor,
                            overlayStyle: rule?.overlayStyle,
                            rotationStyle: rule?.rotationStyle
                        )
                    }
                }
            }
        }

        if state.isKnobing {
            if let lockPos = initialTouchPositionCarbon {
                CGWarpMouseCursorPosition(lockPos)
            }

            if let target = currentTarget, target.axRole == "ControlPanel" {
                let knobState = KnobState(
                    current: KnobCore(angle: currentAngle),
                    previous: KnobCore(angle: previousAngle)
                )
                let delta = knobState.deltaAngle
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("KnobPanelDidRotate"),
                    object: nil,
                    userInfo: ["delta": delta]
                )
                
                ControlPanelViewModel.shared.receiveRotationDelta(delta)
                
                self.currentAngle = currentAngle
                previousAngle = currentAngle
                return
            }

            let radius = calculateRawRadius(points: scaledPoints)
            self.currentRadius = radius

            // 1. Resolve default base scale dynamically from radius
            var baseScale: Double?
            if scaledPoints.count >= 2 {
                var resolvedZoneIndex = currentZoneIndex
                let defaultBaseScale: Double?
                
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
                    if let target = currentTarget,
                       let rule = RuleLibrary.shared.lookup(for: target.ruleKey),
                       rule.configType == .double {
                        let newTranslator = makeTranslator(for: target, rule: rule, radius: radius)
                        self.currentTranslator = newTranslator
                        translator = newTranslator
                    }
                }
                
                // Apply override if available
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
                
                if let resolved = baseScale {
                    self.lastResolvedBaseScale = resolved
                }
            } else {
                // Lock multiplier for 1-finger continuation
                baseScale = self.lastResolvedBaseScale
            }

            // 2. 检查死区判定
            guard let activeBaseScale = baseScale else {
                // radius < minRadius, 进入死区：丢弃本帧变化，Overlay UI 变灰
                overlayController.update(angle: currentAngle, radius: radius, isDeadzone: true, scale: self.lastResolvedBaseScale)
                self.currentAngle = currentAngle
                previousAngle = currentAngle
                return
            }

            // 3. 读取系统面板灵敏度并合成最终步长倍率
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

            // 4. 注入翻译事件
            let knobState = KnobState(
                current: KnobCore(angle: currentAngle),
                previous: KnobCore(angle: previousAngle)
            )
            let deltaAngle = abs(knobState.deltaAngle)
            let direction: RotationDirection = knobState.deltaAngle >= 0 ? .clockwise : .counterClockwise

            translator.apply(units: deltaAngle, direction: direction)

            overlayController.update(angle: currentAngle, radius: radius, isDeadzone: false, scale: activeBaseScale)

            self.currentAngle = currentAngle
            previousAngle = currentAngle

            writeVerboseLog("[KnobStateManager] applied delta=\(deltaAngle) dir=\(direction) scale=\(finalScale)")
        }
    }

    func onMultitouchEnded() {
        guard state != .inactive else { return }
        
        if state == .customizing {
            NotificationCenter.default.post(
                name: NSNotification.Name("CustomizerRadiusDidUpdate"),
                object: nil,
                userInfo: ["radius": nil]
            )
            return
        }
        isInterceptingGestures = false
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        gestureClassifier.processTouchesEnded()
        initialTouchPositionCarbon = nil

        if state.isKnobing, let target = currentTarget {
            transition(to: .cooling(target: target))
            if target.axRole != "ControlPanel" {
                overlayController.fadeOut { [weak self] in
                    self?.startCoolingTimer()
                }
            } else {
                startCoolingTimer()
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

    private func setupEventTap() {
        guard eventTap == nil else { return }
        
        let eventMask = UInt64(1 << CGEventType.keyDown.rawValue) |
                        UInt64(1 << CGEventType.keyUp.rawValue) |
                        UInt64(1 << 29) | // gesture
                        UInt64(1 << 19) | // magnify
                        UInt64(1 << 18)   // rotate
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let manager = Unmanaged<KnobStateManager>.fromOpaque(refcon).takeUnretainedValue()
                
                if type == .tapDisabledByTimeout {
                    manager.reEnableEventTap()
                    return nil
                }
                
                if manager.handleEventTap(proxy: proxy, type: type, event: event) {
                    return nil
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPointer
        ) else {
            writeDebugLog("[KnobStateManager] Failed to create event tap")
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = self.runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        CGEvent.tapEnable(tap: tap, enable: false)
    }

    func reEnableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            writeDebugLog("[KnobStateManager] Re-enabled event tap after timeout/disable event")
        }
    }

    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Bool {
        // Skip events posted by our own translators
        let sourceUserData = event.getIntegerValueField(.eventSourceUserData)
        guard sourceUserData != 0xDEADC0DE else { return false }
        
        // Check key events for customization trigger first
        if type == .keyDown || type == .keyUp {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == 8 && type == .keyDown { // 'C' keycode
                if state.isKnobing || state.isCooling {
                    DispatchQueue.main.async { [weak self] in
                        self?.enterCustomization()
                    }
                    return true
                }
            }
        }
        
        if state == .customizing {
            // Let all keyboard events pass through to Customizer window
            return false
        }
        
        // Block zoom (magnify), rotate, and general gestures during knobing/interception
        let typeVal = type.rawValue
        if typeVal == 29 || typeVal == 19 || typeVal == 18 {
            if state.isKnobing || isInterceptingGestures {
                writeDebugLog("[KnobStateManager] Swallowed gesture event of type: \(typeVal) (knobing: \(state.isKnobing), intercepting: \(isInterceptingGestures))")
                return true
            }
        }
        
        guard state.isKnobing || isInterceptingGestures else { return false }
        
        guard type == .keyDown || type == .keyUp else { return false }
        
        // If keyboard multiplier is disabled in settings, do not block or handle key events
        guard AppSettings.shared.enableKeyboardNumberMultiplier else { return false }
        
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        
        let targetKeyCodes: Set<CGKeyCode> = [18, 19, 20, 21, 22, 23, 25, 26, 28, 123, 124, 125, 126]
        guard targetKeyCodes.contains(keyCode) else { return false }
        
        if type == .keyDown {
            DispatchQueue.main.async { [weak self] in
                self?.handleDirectKeyPress(keyCode: keyCode)
            }
        }
        return true
    }

    func handleDirectKeyPress(keyCode: CGKeyCode) {
        guard state.isKnobing, let target = currentTarget else { return }
        
        let key = persistentKey(for: target, zoneIndex: currentZoneIndex)
        let currentVal: Double
        
        // Resolve default base scale dynamically
        let defaultBaseScale: Double
        switch activeScaleConfig {
        case .fixed(let val):
            defaultBaseScale = val
        case .zones(let zones):
            if currentZoneIndex >= 0 && currentZoneIndex < zones.count {
                defaultBaseScale = zones[currentZoneIndex].scale
            } else {
                defaultBaseScale = 1.0
            }
        case .linear:
            defaultBaseScale = 1.0
        }
        
        if let overrideValue = UserDefaults.standard.object(forKey: key) as? Double {
            currentVal = overrideValue
        } else {
            currentVal = defaultBaseScale
        }
        
        var updatedVal: Double? = nil
        
        if keyCode == 18 {
            // Key 1 -> Reset to safe value 1.0
            updatedVal = 1.0
        } else if let num = getNumberValue(for: keyCode) {
            // Keys 2-9
            updatedVal = Double(num)
        } else if let delta = getArrowDelta(for: keyCode) {
            // Arrow keys
            let rawNewVal = currentVal + delta
            updatedVal = max(0.1, (rawNewVal * 10).rounded() / 10)
        }
        
        if let nextVal = updatedVal {
            UserDefaults.standard.set(nextVal, forKey: key)
            self.lastResolvedBaseScale = nextVal
            
            // Apply immediately to currentTranslator scale
            if let translator = currentTranslator {
                let globalSens = UserDefaults.standard.object(forKey: "globalSensitivity") as? Double ?? 1.0
                let settingsSensitivity: Double
                switch target.axRole {
                case "AXSlider":
                    settingsSensitivity = UserDefaults.standard.object(forKey: "sliderSensitivity") as? Double ?? globalSens
                case "AXProgressIndicator":
                    settingsSensitivity = UserDefaults.standard.object(forKey: "progressSensitivity") as? Double ?? globalSens
                default:
                    settingsSensitivity = globalSens
                }
                translator.scale = nextVal * settingsSensitivity
            }
            
            // Update Overlay UI immediately
            overlayController.update(
                angle: self.currentAngle,
                radius: self.currentRadius,
                isDeadzone: false,
                scale: nextVal
            )
        }
    }

    private func getNumberValue(for keyCode: CGKeyCode) -> Int? {
        let keyMapping: [CGKeyCode: Int] = [
            19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
        ]
        return keyMapping[keyCode]
    }

    private func getArrowDelta(for keyCode: CGKeyCode) -> Double? {
        if keyCode == 126 { return 1.0 }   // Up
        if keyCode == 125 { return -1.0 }  // Down
        if keyCode == 124 { return 0.1 }   // Right
        if keyCode == 123 { return -0.1 }  // Left
        return nil
    }

    // MARK: - Helper Methods
    
    func isAdjustable(target: DetectedTarget) -> Bool {
        if target.axRole == "ControlPanel" {
            return true
        }
        
        // 1. 如果命中规则库中的任何规则，说明用户/内置规则已为此进行了特化，必然是可调节的
        if RuleLibrary.shared.lookup(for: target.ruleKey) != nil {
            return true
        }
        
        // 2. 如果具备 AX 元素，根据 AX 角色与属性判定
        if let element = target.element {
            // A. Role 白名单中的标准可调节控件
            let role = TargetDetector.getString(from: element, attribute: kAXRoleAttribute) ?? ""
            let adjustableRoles: Set<String> = ["AXSlider", "AXScrollBar", "AXValueIndicator", "AXStepper", "AXDial", "AXIncrementor"]
            if adjustableRoles.contains(role) {
                return true
            }
            
            // B. 具备最小值和最大值的数值控件
            if TargetDetector.getDouble(from: element, attribute: kAXMinValueAttribute) != nil &&
               TargetDetector.getDouble(from: element, attribute: kAXMaxValueAttribute) != nil {
                return true
            }
            
            // C. 具备可写的 AXValue 属性
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue {
                return true
            }
            
            // D. 支持递增/递减 Action
            var actions: CFArray?
            if AXUIElementCopyActionNames(element, &actions) == .success,
               let actionList = actions as? [String],
               (actionList.contains(kAXIncrementAction) || actionList.contains(kAXDecrementAction)) {
                return true
            }
        }
        
        return false
    }
    
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

    private func makeTranslator(for target: DetectedTarget, rule: ControlRule?, radius: Double = 0.0) -> InputTranslator {
        var translation = rule?.translation ?? autoDetectTranslation(for: target)
        var scale = rule?.scaleConfig?.resolve() ?? 1.0
        var isInverted = rule?.invert ?? false

        if let rule = rule {
            switch rule.configType {
            case .single:
                if let single = rule.singleConfig {
                    translation = single.translation
                    scale = single.unitPerDegree
                    let isDefaultCW = (single.clockwiseAction == "arrowUp" || single.clockwiseAction == "arrowRight" || single.clockwiseAction == "scrollUp" || single.clockwiseAction == "swipeUp" || single.clockwiseAction == "swipeRight" || single.clockwiseAction == "increase")
                    isInverted = !isDefaultCW
                }
            case .double:
                if let double = rule.doubleConfig {
                    let isOuter = radius > (double.inner.maxRadius + double.inner.margin)
                    let activeKnob = isOuter ? double.outer : double.inner
                    translation = activeKnob.translation
                    scale = activeKnob.unitPerDegree
                    let isDefaultCW = (activeKnob.clockwiseAction == "arrowUp" || activeKnob.clockwiseAction == "arrowRight" || activeKnob.clockwiseAction == "scrollUp" || activeKnob.clockwiseAction == "swipeUp" || activeKnob.clockwiseAction == "swipeRight" || activeKnob.clockwiseAction == "increase")
                    isInverted = !isDefaultCW
                }
            case .linear:
                if let linear = rule.linearConfig {
                    translation = linear.translation
                    scale = ScaleResolver.resolveLinear(radius: radius, config: ScaleConfigLinear(minRadius: linear.minRadius, maxRadius: linear.maxRadius, minScale: linear.minScale, maxScale: linear.maxScale)) ?? linear.minScale
                    let isDefaultCW = (linear.clockwiseAction == "arrowUp" || linear.clockwiseAction == "arrowRight" || linear.clockwiseAction == "scrollUp" || linear.clockwiseAction == "swipeUp" || linear.clockwiseAction == "swipeRight" || linear.clockwiseAction == "increase")
                    isInverted = !isDefaultCW
                }
            }
        }

        switch translation {
        case .axWrite:
            guard let element = target.element,
                  let minV = TargetDetector.getDouble(from: element, attribute: kAXMinValueAttribute),
                  let maxV = TargetDetector.getDouble(from: element, attribute: kAXMaxValueAttribute)
            else {
                // AX 元素不可用，降级到滚轮
                return ScrollWheelTranslator(axis: .vertical, scale: scale, invert: isInverted)
            }
            return AXWriteTranslator(element: element, minValue: minV, maxValue: maxV, scale: scale, invert: isInverted)

        case .scrollWheelVertical:
            return ScrollWheelTranslator(axis: .vertical, scale: scale, invert: isInverted)

        case .scrollWheelHorizontal:
            return ScrollWheelTranslator(axis: .horizontal, scale: scale, invert: isInverted)

        case .arrowKeyUpDown:
            return ArrowKeyTranslator(axis: .upDown, scale: scale, invert: isInverted)

        case .arrowKeyLeftRight:
            return ArrowKeyTranslator(axis: .leftRight, scale: scale, invert: isInverted)

        case .swipeVertical:
            // 使用滚轮模拟，直到专用 swipe 实现完成
            return ScrollWheelTranslator(axis: .vertical, scale: scale, invert: isInverted)

        case .swipeHorizontal:
            return ScrollWheelTranslator(axis: .horizontal, scale: scale, invert: isInverted)
        }
    }

    private func autoDetectTranslation(for target: DetectedTarget) -> InputTranslation {
        guard let element = target.element else { return .scrollWheelVertical }
        return TargetDetector.autoDetectTranslation(for: element)
    }
}

// [DEBUG-LOG-HARNESS]
private let debugLogQueue = DispatchQueue(label: "com.phantomknob.debugLogQueue")

func writeDebugLog(_ message: String) {
    debugLogQueue.async {
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
}

func writeVerboseLog(_ message: String) {
    #if DEBUG
    writeDebugLog(message)
    #endif
}
