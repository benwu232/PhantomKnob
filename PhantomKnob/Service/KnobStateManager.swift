// PhantomKnob/Service/KnobStateManager.swift
import Foundation
import AppKit
import Combine
import ApplicationServices
import os
#if canImport(Sentry)
import Sentry
#endif

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
    var initialTouchPosition: CGPoint?
    var initialTouchPositionCarbon: CGPoint? // 锁定鼠标 of Carbon coordinate (top-left origin)
    private var previousAngle: Double = 0
    private var isOptionHoldActive = false
    private var coolingTimer: Timer?
    var fixedCenter: CGPoint?
    var fingerIdx1: Int?
    var fingerIdx2: Int?
    
    var currentZoneIndex: Int = 0
    var activeScaleConfig: ScaleConfig = .fixed(1.0)
    var lastResolvedBaseScale: Double = 1.0
    private var currentRadius: Double = 0.0
    private var eventTap: CFMachPort?
    private var hasShownEventTapErrorAlert = false
    private var runLoopSource: CFRunLoopSource?
    var isInterceptingGestures = false
    private var wasInactiveBeforePanelShow = false
    
    // For unit testing click simulation verification
    var didSimulateClickForTest = false
    var didSimulateReturnForTest = false
    private var didFocusCurrentTextField = false
    private var isOptionHoldInactive = false
    
    private let featureGate: FeatureGate
    private var activationWorkItem: DispatchWorkItem?
    private var popoverCountdownWorkItem: DispatchWorkItem?
    private var sessionTimer: Timer?
    var sessionTimeRemaining: Double = 0.0

    // Mockable multitouch control for unit testing
    var startMultitouch: () -> Void = { MultitouchManager.shared.start() }
    var stopMultitouch: () -> Void = { MultitouchManager.shared.stop() }

    // Mockable accessibility check for unit testing
    var isProcessTrusted: () -> Bool = {
        let env = ProcessInfo.processInfo.environment
        let isTesting = env.keys.contains { $0.range(of: "xctest", options: .caseInsensitive) != nil }
        if isTesting {
            return true
        }
        return AXIsProcessTrusted()
    }

    private var cancellables = Set<AnyCancellable>()

    init(
        targetDetector: TargetDetector,
        gestureClassifier: GestureClassifier,
        overlayController: OverlayController,
        statusBarController: StatusBarController,
        touchHandler: GlobalTouchHandler,
        featureGate: FeatureGate = .shared
    ) {
        self.targetDetector = targetDetector
        self.gestureClassifier = gestureClassifier
        self.overlayController = overlayController
        self.statusBarController = statusBarController
        self.touchHandler = touchHandler
        self.featureGate = featureGate

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
            for: NSNotification.Name("KnobDidUpdate")
        )
        .sink { [weak self] notification in
            guard let self = self,
                  let updatedKnob = notification.userInfo?["knob"] as? Knob else { return }
            self.handleKnobHotReload(updatedKnob)
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("LicenseStateDidChange"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.activationWorkItem?.cancel()
                self.activationWorkItem = nil
                self.popoverCountdownWorkItem?.cancel()
                self.popoverCountdownWorkItem = nil
                self.statusBarController.dismissFreePopover()
                self.sessionTimer?.invalidate()
                self.sessionTimer = nil
                self.transition(to: .inactive)
                self.stopMultitouch()
                self.currentTarget = nil
                self.currentTranslator = nil
                self.overlayController.hide()
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
        stopMultitouch()
        overlayController.hide()
    }

    func toggleMode() {
        PKLogger.knob.debug("toggleMode() called, current state: \(String(describing: self.state))")
        if activationWorkItem != nil {
            PKLogger.knob.debug("Cancelling activation delay")
            activationWorkItem?.cancel()
            activationWorkItem = nil
            popoverCountdownWorkItem?.cancel()
            popoverCountdownWorkItem = nil
            statusBarController.dismissFreePopover()
            statusBarController.updateState(.inactive)
            return
        }
        
        if isOptionHoldActive {
            PKLogger.knob.debug("Converting temporary Option Hold to persistent activated state")
            isOptionHoldActive = false
            if case .cooling = state {
                transition(to: .activated)
                startSessionLimitTimer()
            }
        } else if isOptionHoldInactive {
            PKLogger.knob.debug("Converting temporary Option Inactive to persistent inactive state")
            isOptionHoldInactive = false
        } else if case .inactive = state {
            let isTrusted = isProcessTrusted()
            guard isTrusted else {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
                return
            }
            
            let delay = featureGate.activationDelay
            if delay > 0.0 {
                PKLogger.knob.debug("Scheduling activation after delay of \(delay)s")
                statusBarController.updateStateActivating(secondsRemaining: delay)
                statusBarController.showFreeActivatingPopover(secondsRemaining: delay)
                
                let countdownItem = DispatchWorkItem { [weak self] in
                    self?.statusBarController.showFreeActivatingPopover(secondsRemaining: delay - 1.0)
                }
                popoverCountdownWorkItem = countdownItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: countdownItem)
                
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.popoverCountdownWorkItem?.cancel()
                    self.popoverCountdownWorkItem = nil
                    self.activationWorkItem = nil
                    self.completeActivation()
                }
                activationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            } else {
                completeActivation()
            }
        } else {
            PKLogger.knob.debug("Transitioning to inactive")
            
            activationWorkItem?.cancel()
            activationWorkItem = nil
            popoverCountdownWorkItem?.cancel()
            popoverCountdownWorkItem = nil
            statusBarController.dismissFreePopover()
            
            sessionTimer?.invalidate()
            sessionTimer = nil
            
            transition(to: .inactive)

            // 停止后台多点触控捕获
            stopMultitouch()

            currentTarget = nil
            currentTranslator = nil
            overlayController.hide()
            targetDetector.clearCache()
        }
    }
    
    private func completeActivation() {
        PKLogger.knob.debug("Transitioning to activated")
        transition(to: .activated)
        statusBarController.dismissFreePopover()
        
        // 启动后台多点触控捕获
        startMultitouch()
        
        startSessionLimitTimer()
    }
    
    private func startSessionLimitTimer() {
        if sessionTimer != nil { return }
        
        guard let limit = featureGate.sessionLimitSeconds else { return }
        sessionTimeRemaining = limit
        
        statusBarController.updateVersionItem(timeRemaining: sessionTimeRemaining)
        
        let interval = min(1.0, limit)
        sessionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sessionTimeRemaining -= interval
            self.statusBarController.updateVersionItem(timeRemaining: self.sessionTimeRemaining)
            
            if self.sessionTimeRemaining <= 0 {
                PKLogger.knob.debug("Session limit reached. Automatically deactivating.")
                self.toggleMode()
                self.statusBarController.showFreeExpiredPopover()
            }
        }
    }

    func transition(to newState: KnobGlobalState) {
        #if canImport(Sentry)
        SentrySDK.addBreadcrumb(Breadcrumb(level: .info, category: "state"))
        #endif
        state = newState
        let targetName = currentTarget?.displayName
        statusBarController.updateState(newState, targetName: targetName)
        
        if eventTap == nil {
            setupEventTap()
        }
        
        if let tap = eventTap {
            if newState != .inactive {
                CGEvent.tapEnable(tap: tap, enable: true)
                PKLogger.knob.debug("Enabled event tap for state: \(String(describing: newState))")
            } else {
                CGEvent.tapEnable(tap: tap, enable: false)
                PKLogger.knob.debug("Disabled event tap for state: \(String(describing: newState))")
            }
        }
        
        if case .knobing(let target) = newState {
            if target.axRole == "ControlPanel" {
                ControlPanelViewModel.shared.isGestureActive = true
            } else {
                ControlPanelViewModel.shared.isGestureActive = false
            }
            // 针对文本输入与静态文本输入，且只有在需要模拟键盘事件时，才自动注入一次鼠标点击以聚焦
            if target.axRole == "AXTextField" || target.axRole == "AXStaticText" {
                let knob = KnobCustomizer.shared.knob(for: target.knobKey)
                
                // 静态文本通常为只读 Label，只有在其被显式配置了专属配置时，才允许进行模拟点击聚焦以接收键盘输入
                // 注意：如果 knob 的 axRole 是 "unknown"，说明它仅匹配到了 App 的全局兜底配置，不算作专门为该静态文本配置的专属配置
                let isStaticText = (target.axRole == "AXStaticText")
                let hasSpecificKnob = (knob != nil && knob?.key.axRole != "unknown")
                
                if !isStaticText || hasSpecificKnob {
                    let translation = determineTranslation(for: target, knob: knob, radius: self.currentRadius)
                    // 仅在微调数值的键盘上下键模式（arrowKeyUpDown）下才进行点击聚焦
                    // 左右方向键模式（arrowKeyLeftRight）常用于时间轴左右逐帧移动，在此模式下绝对不产生点击，防止重新定位时间轴
                    if translation == .arrowKeyUpDown {
                        if let touchPos = initialTouchPosition {
                            simulateClick(at: touchPos)
                            self.didFocusCurrentTextField = true
                        }
                    }
                }
            }
        } else if case .cooling = newState {
            if self.didFocusCurrentTextField {
                self.simulateReturnKey()
                self.didFocusCurrentTextField = false
            }
            ControlPanelViewModel.shared.isGestureActive = false
        } else {
            self.didFocusCurrentTextField = false
            ControlPanelViewModel.shared.isGestureActive = false
        }
    }

    private func handleAppSwitch() {
        guard state != .inactive, state != .customizing else { return }
        transition(to: .activated)
        currentTarget = nil
        currentTranslator = nil
        overlayController.hide()
        targetDetector.clearCache()
    }

    private func handleKnobPanelDidShow() {
        PKLogger.knob.debug("handleKnobPanelDidShow() called, current state: \(String(describing: self.state))")
        if case .inactive = state {
            wasInactiveBeforePanelShow = true
            toggleMode()
        } else {
            wasInactiveBeforePanelShow = false
        }
    }

    private func handleKnobPanelDidHide() {
        PKLogger.knob.debug("handleKnobPanelDidHide() called, current state: \(String(describing: self.state)), wasInactiveBeforePanelShow: \(self.wasInactiveBeforePanelShow)")
        if state == .customizing {
            overlayController.hide()
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
        
        // 保持 Overlay 在原地常驻不消失，并终止任何正在运行的淡出动画
        overlayController.keepVisible()
        
        transition(to: .customizing)
        
        // 弹出配置面板并传入当前的真实锁定中心（屏幕像素坐标）
        CustomizerHUDWindowController.shared.show(for: target, overlayCenter: overlayController.fixedCenter)
    }

    private func handleKnobHotReload(_ knob: Knob) {
        PKLogger.knob.debug("[DEBUG-color-reload] handleKnobHotReload called, state: \(String(describing: self.state)), knob key: \(String(describing: knob.key)), themeColor: \(knob.themeColor ?? "nil")")
        
        guard let target = currentTarget else { return }
        
        if state == .customizing {
            // 自定义状态下，直接使用刚修改的配置更新 Overlay，并根据配置计算一个安全的静态 Radius，防止 radius 为 0.0 时 Overlay 不可见
            let renderRadius: Double
            if self.currentRadius > 0 {
                renderRadius = self.currentRadius
            } else {
                switch knob.configType {
                case .single:
                    renderRadius = knob.singleConfig?.minRadius ?? 16.0
                case .double:
                    renderRadius = knob.doubleConfig?.outer.maxRadius ?? 24.0
                case .cvk:
                    renderRadius = knob.cvkConfig?.maxRadius ?? 24.0
                }
            }
            
            // 重新实例化当前 Translator
            let newTranslator = makeTranslator(for: target, knob: knob, radius: renderRadius)
            newTranslator.scale = currentTranslator?.scale ?? 1.0
            self.currentTranslator = newTranslator
            
            let color = resolveThemeColor(for: knob, zoneIndex: currentZoneIndex, radius: renderRadius)
            overlayController.update(
                angle: self.currentAngle,
                radius: renderRadius,
                isDeadzone: false,
                scale: self.lastResolvedBaseScale,
                themeColor: color,
                outerThemeColor: knob.cvkConfig?.outerThemeColor,
                innerThemeColor: knob.cvkConfig?.innerThemeColor,
                configType: knob.configType
            )
            return
        }
        
        // 否则（非自定义状态下），走严格匹配过滤
        guard let resolvedKnob = KnobCustomizer.shared.knob(for: target.knobKey),
              resolvedKnob.key.matches(knob.key) else { return }
        
        // 1. 重新实例化当前 Translator
        let newTranslator = makeTranslator(for: target, knob: knob, radius: self.currentRadius)
        newTranslator.scale = currentTranslator?.scale ?? 1.0
        self.currentTranslator = newTranslator
        
        // 2. 重新解析 ScaleConfig
        switch knob.configType {
        case .single:
            if let single = knob.singleConfig {
                self.activeScaleConfig = .fixed(single.unitPerDegree)
            }
        case .double:
            if let double = knob.doubleConfig {
                self.activeScaleConfig = .zones([
                    RadiusZone(minRadius: double.inner.minRadius, maxRadius: double.inner.maxRadius, margin: double.inner.margin, scale: double.inner.unitPerDegree),
                    RadiusZone(minRadius: double.outer.minRadius, maxRadius: double.outer.maxRadius, margin: double.outer.margin, scale: double.outer.unitPerDegree)
                ])
            }
        case .cvk:
            if let cvk = knob.cvkConfig {
                self.activeScaleConfig = .cvk(ScaleConfigCVK(minRadius: cvk.minRadius, maxRadius: cvk.maxRadius, minScale: cvk.minScale, maxScale: cvk.maxScale))
            }
        }
        
        // 3. 即时刷新 Overlay UI 配色与样式
        if isInterceptingGestures {
            let color = resolveThemeColor(for: knob, zoneIndex: currentZoneIndex, radius: currentRadius)
            overlayController.show(
                at: initialTouchPosition ?? .zero,
                targetName: target.displayName.isEmpty ? nil : target.displayName,
                scale: lastResolvedBaseScale,
                themeColor: color,
                overlayStyle: knob.overlayStyle,
                rotationStyle: knob.rotationStyle,
                outerThemeColor: knob.cvkConfig?.outerThemeColor,
                innerThemeColor: knob.cvkConfig?.innerThemeColor,
                configType: knob.configType
            )
        }
    }

    // MARK: - GlobalTouchDelegate

    func onGlobalModifierOptionChanged(isPressed: Bool) {
        // Option Hold 模式支持
        if isPressed {
            if !isOptionHoldActive && !isOptionHoldInactive {
                if state == .inactive {
                    isOptionHoldActive = true
                    PKLogger.knob.debug("Option key held, starting background multitouch capture (temporary active)")
                    transition(to: .activated)
                    startMultitouch()
                } else if state == .activated {
                    isOptionHoldInactive = true
                    PKLogger.knob.debug("Option key held, stopping background multitouch capture (temporary inactive)")
                    transition(to: .inactive)
                    stopMultitouch()
                    overlayController.hide()
                    currentTarget = nil
                    currentTranslator = nil
                    targetDetector.clearCache()
                }
            }
        } else {
            if isOptionHoldActive {
                isOptionHoldActive = false
                PKLogger.knob.debug("Option key released, stopping background multitouch capture (restoring inactive)")
                transition(to: .inactive)
                stopMultitouch()
                overlayController.hide()
                currentTarget = nil
                currentTranslator = nil
                targetDetector.clearCache()
            } else if isOptionHoldInactive {
                isOptionHoldInactive = false
                PKLogger.knob.debug("Option key released, restoring background multitouch capture (restoring active)")
                transition(to: .activated)
                startMultitouch()
            }
        }
    }

    func onGlobalScroll(phase: NSEvent.Phase, deltaX: CGFloat, deltaY: CGFloat) {
        // 保留系统底层原生滚轮调节的兜底支持
    }

    // MARK: - MultitouchEventDelegate (硬件绝对坐标多指捕获)

    func onMultitouchBegan(points: [Int: CGPoint]) {
        PKLogger.knob.debug("onMultitouchBegan: points count = \(points.count), state = \(String(describing: self.state))")
        guard state != .inactive else { return }
        
        if points.count >= 2 {
            NotificationCenter.default.post(
                name: NSNotification.Name("TouchpadCoordinatesValidated"),
                object: nil,
                userInfo: ["points": points]
            )
        }
        
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

        let isUserGuidePractice = UserGuideWindowController.shared.isVisible && {
            if let guideVM = UserGuideWindowController.shared.viewModel {
                return guideVM.currentStep == 2 || guideVM.currentStep == 3
            }
            return false
        }()

        if KnobPanelWindowController.shared.isVisible || isUserGuidePractice {
            var identifier: String? = nil
            var displayName = "控制面板"
            
            if UserGuideWindowController.shared.isVisible {
                if let guideVM = UserGuideWindowController.shared.viewModel {
                    if guideVM.currentStep == 2 {
                        identifier = "VolumeKnob"
                        displayName = "音量练习"
                    } else if guideVM.currentStep == 3 {
                        switch guideVM.hoveredKnob {
                        case .doubleKnob:
                            identifier = "DoubleKnob"
                            displayName = "双环旋钮"
                        case .cvkKnob:
                            identifier = "CVKKnob"
                            displayName = "无级变速旋钮"
                        case .volumeKnob:
                            identifier = "VolumeKnob"
                            displayName = "音量练习"
                        case .none:
                            identifier = nil
                            displayName = "控制面板"
                        }
                    }
                }
            } else if KnobPanelWindowController.shared.isVisible {
                switch ControlPanelViewModel.shared.focusedVariable {
                case .volume:
                    identifier = "VolumeKnob"
                    displayName = "系统音量"
                case .brightness:
                    identifier = "BrightnessKnob"
                    displayName = "屏幕亮度"
                case .keyboardBacklight:
                    identifier = "KeyboardBacklightKnob"
                    displayName = "键盘灯"
                case nil:
                    identifier = nil
                    displayName = "控制面板"
                }
            }
            
            let target = DetectedTarget(
                bundleID: "com.phantomknob.controlpanel",
                axRole: "ControlPanel",
                identifier: identifier,
                displayName: displayName,
                element: nil,
                parentChain: []
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
                PKLogger.knob.debug("Enabled event tap on begin (ControlPanel mode)")
            }
            return
        }

        // 1. 探测目标元素
        let detectedTarget = targetDetector.detectTargetAtMousePosition()

        // 2. 创建 DetectedTarget（无 AX 元素时用当前 app 信息填充）
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName ?? ""
        let bundleID = frontmostApp?.bundleIdentifier ?? ""
        
        var parentChain: [ParentNodeInfo] = []
        if detectedTarget == nil {
            if let pageMode = KnobStateManager.getActiveWindowPageMode(for: bundleID) {
                parentChain = [ParentNodeInfo(axRole: "AXWindow", displayName: pageMode)]
            }
        } else if let detected = detectedTarget {
            parentChain = detected.parentChain
        }

        let target = detectedTarget ?? DetectedTarget(
            bundleID: bundleID,
            axRole: "unknown",
            identifier: nil,
            displayName: appName,
            element: nil,
            parentChain: parentChain
        )

        // 检查是否是从冷却状态恢复（如果目标相同，则跳过 5° 的激活阈值）
        var isResuming = false
        if case .cooling(let coolingTarget) = state {
            if target.knobKey == coolingTarget.knobKey {
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
                PKLogger.knob.debug("Enabled event tap on begin (adjustable/option hold)")
            }
        } else {
            isInterceptingGestures = false
        }

        // Calculate scaled points and initial radius early to resolve correct translator
        let scaledPoints = scaleCoordinates(points)
        let initialRadius = calculateRawRadius(points: scaledPoints)

        // 3. 查配置库（未命中则自动探测）
        let knob = KnobCustomizer.shared.knob(for: target.knobKey)

        // 4. 创建 InputTranslator
        let translator = makeTranslator(for: target, knob: knob, radius: initialRadius)
        currentTranslator = translator
 
        // 解析并缓存 ScaleConfig 与状态变量重置
        let resolvedScaleConfig: ScaleConfig
        if let knobScaleConfig = knob?.scaleConfig {
            switch knobScaleConfig {
            case .fixed(let val):
                if val == 1.0 {
                    resolvedScaleConfig = AppSettings.shared.activeScheme == "cvk"
                        ? .cvk(AppSettings.shared.cvk)
                        : .zones(AppSettings.shared.fixed.zones)
                } else {
                    resolvedScaleConfig = .fixed(val)
                }
            default:
                resolvedScaleConfig = knobScaleConfig
            }
        } else {
            if let r = knob {
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
                case .cvk:
                    if let l = r.cvkConfig {
                        resolvedScaleConfig = .cvk(ScaleConfigCVK(minRadius: l.minRadius, maxRadius: l.maxRadius, minScale: l.minScale, maxScale: l.maxScale))
                    } else {
                        resolvedScaleConfig = .cvk(AppSettings.shared.cvk)
                    }
                }
            } else {
                resolvedScaleConfig = AppSettings.shared.activeScheme == "cvk"
                    ? .cvk(AppSettings.shared.cvk)
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
                let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: currentRadius) }
                overlayController.show(
                    at: mouseLoc,
                    targetName: target.displayName.isEmpty ? nil : target.displayName,
                    scale: self.lastResolvedBaseScale,
                    themeColor: color,
                    overlayStyle: knob?.overlayStyle,
                    rotationStyle: knob?.rotationStyle,
                    outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                    innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                    configType: knob?.configType ?? .single
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
            
            if points.count >= 2 {
                let scaledPointsForCalc = scaleCoordinates(points)
                if let currentAngle = calculateRawAngle(points: scaledPointsForCalc) {
                    let knob = currentTarget.flatMap { KnobCustomizer.shared.knob(for: $0.knobKey) }
                    
                    let nextVal: Double?
                    if let knob = knob {
                        switch knob.configType {
                        case .single:
                            nextVal = knob.singleConfig?.unitPerDegree
                        case .double:
                            if let double = knob.doubleConfig {
                                let zones = [
                                    RadiusZone(minRadius: double.inner.minRadius, maxRadius: double.inner.maxRadius, margin: double.inner.margin, scale: double.inner.unitPerDegree),
                                    RadiusZone(minRadius: double.outer.minRadius, maxRadius: double.outer.maxRadius, margin: double.outer.margin, scale: double.outer.unitPerDegree)
                                ]
                                nextVal = ScaleResolver.resolveHysteresis(radius: radius, zones: zones, currentZoneIndex: &currentZoneIndex)
                            } else {
                                nextVal = nil
                            }
                        case .cvk:
                            if let cvk = knob.cvkConfig {
                                let config = ScaleConfigCVK(minRadius: cvk.minRadius, maxRadius: cvk.maxRadius, minScale: cvk.minScale, maxScale: cvk.maxScale)
                                nextVal = ScaleResolver.resolveCVK(radius: radius, config: config)
                            } else {
                                nextVal = nil
                            }
                        }
                    } else {
                        nextVal = nil
                    }
                    
                    if currentTranslator == nil, let t = currentTarget {
                        currentTranslator = knob.flatMap { makeTranslator(for: t, knob: $0, radius: radius) }
                    }
                    
                    if let activeScale = nextVal, let translator = currentTranslator {
                        translator.scale = activeScale
                        let deltaAngle = abs(currentAngle - previousAngle)
                        var correctedDelta = deltaAngle
                        while correctedDelta < -180 { correctedDelta += 360 }
                        while correctedDelta > 180 { correctedDelta -= 360 }
                        
                        let direction: RotationDirection = (currentAngle - previousAngle) >= 0 ? .clockwise : .counterClockwise
                        translator.apply(units: abs(correctedDelta), direction: direction)
                        
                        let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: radius) }
                        overlayController.update(
                            angle: currentAngle,
                            radius: radius,
                            isDeadzone: false,
                            scale: activeScale,
                            themeColor: color,
                            outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                            innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                            configType: knob?.configType ?? .single
                        )
                    }
                    self.currentAngle = currentAngle
                    previousAngle = currentAngle
                }
            }
            return
        }
        
        guard state != .inactive, var translator = currentTranslator else { return }
        
        if points.count >= 2 {
            NotificationCenter.default.post(
                name: NSNotification.Name("TouchpadCoordinatesValidated"),
                object: nil,
                userInfo: ["points": points]
            )
        }

        let scaledPoints = scaleCoordinates(points)
        guard let currentAngle = calculateRawAngle(points: scaledPoints) else { return }

        let currentTouchCount = scaledPoints.count
        // 单指重新升级回双指时，重新缓存双指的 ID 对应关系以备下一次抬指匹配
        if currentTouchCount >= 2 {
            let (_, idx1, idx2) = KnobAlgorithm().calKnob(scaledPoints)
            self.fingerIdx1 = idx1
            self.fingerIdx2 = idx2
        }

        let isTooClose = scaledPoints.count >= 2 && {
            let (knobCore, _, _) = KnobAlgorithm().calKnob(scaledPoints)
            return knobCore.isValid && knobCore.radius * 2 < 10.0
        }()

        // 🌟 进行手势判定是否升级为 knob
        let mode = gestureClassifier.processTouchesMoved(points: points)
        if mode == .knob && !state.isKnobing {
            if let target = currentTarget {
                transition(to: .knobing(target: target))
                let knob = KnobCustomizer.shared.knob(for: target.knobKey)
                if let mouseLoc = initialTouchPosition {
                    if target.axRole != "ControlPanel" {
                        let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: currentRadius) }
                        overlayController.show(
                            at: mouseLoc,
                            targetName: target.displayName.isEmpty ? nil : target.displayName,
                            scale: self.lastResolvedBaseScale,
                            themeColor: color,
                            overlayStyle: knob?.overlayStyle,
                            rotationStyle: knob?.rotationStyle,
                            outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                            innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                            configType: knob?.configType ?? .single
                        )
                    }
                }
            }
        }

        if state.isKnobing {
            if mode != .knob {
                // 两指靠拢超时，触发退出
                PKLogger.knob.debug("Exiting knobing early because gesture mode is no longer .knob (distance filter timeout)")
                if let target = currentTarget {
                    transition(to: .cooling(target: target))
                    if target.axRole != "ControlPanel" {
                        overlayController.fadeOut { [weak self] in
                            self?.startCoolingTimer()
                        }
                    } else {
                        startCoolingTimer()
                    }
                } else {
                    transition(to: .activated)
                }
                return
            }
            if let lockPos = initialTouchPositionCarbon {
                CGWarpMouseCursorPosition(lockPos)
            }

            let radius = calculateRawRadius(points: scaledPoints)
            self.currentRadius = radius
            let knob = currentTarget.flatMap { KnobCustomizer.shared.knob(for: $0.knobKey) }

            if isTooClose {
                let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: radius) }
                overlayController.update(
                    angle: currentAngle,
                    radius: radius,
                    isDeadzone: false,
                    isTooClose: true,
                    scale: self.lastResolvedBaseScale,
                    themeColor: color,
                    outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                    innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                    configType: knob?.configType ?? .single
                )
                self.currentAngle = currentAngle
                previousAngle = currentAngle
                return
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


            // 1. Resolve default base scale dynamically from radius
            var baseScale: Double?
            if scaledPoints.count >= 2 {
                var resolvedZoneIndex = currentZoneIndex
                let defaultBaseScale: Double?
                
                switch activeScaleConfig {
                case .fixed(let val):
                    var minR = 10.0
                    if let single = knob?.singleConfig {
                        minR = single.minRadius ?? 10.0
                    }
                    if radius < minR {
                        defaultBaseScale = nil
                    } else {
                        defaultBaseScale = val
                    }
                    resolvedZoneIndex = 0
                case .zones(let zones):
                    defaultBaseScale = ScaleResolver.resolveHysteresis(radius: radius, zones: zones, currentZoneIndex: &resolvedZoneIndex)
                case .cvk(let config):
                    defaultBaseScale = ScaleResolver.resolveCVK(radius: radius, config: config)
                    resolvedZoneIndex = 0
                }
                
                if resolvedZoneIndex != currentZoneIndex {
                    currentZoneIndex = resolvedZoneIndex
                    if let target = currentTarget,
                       let knob = KnobCustomizer.shared.knob(for: target.knobKey),
                       knob.configType == .double {
                        let newTranslator = makeTranslator(for: target, knob: knob, radius: radius)
                        self.currentTranslator = newTranslator
                        translator = newTranslator
                    }
                }
                
                // Apply override if available
                if let defaultScale = defaultBaseScale {
                    if let target = currentTarget {
                        let key = persistentKey(for: target, zoneIndex: currentZoneIndex)
                        if let overrideValue = UserDefaults.app.object(forKey: key) as? Double {
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
                let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: radius) }
                overlayController.update(
                    angle: currentAngle,
                    radius: radius,
                    isDeadzone: true,
                    isTooClose: false,
                    scale: self.lastResolvedBaseScale,
                    themeColor: color,
                    outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                    innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                    configType: knob?.configType ?? .single
                )
                self.currentAngle = currentAngle
                previousAngle = currentAngle
                return
            }

            // 3. Apply base scale
            let finalScale = activeBaseScale
            translator.scale = finalScale

            // 4. 注入翻译事件
            let knobState = KnobState(
                current: KnobCore(angle: currentAngle),
                previous: KnobCore(angle: previousAngle)
            )
            let deltaAngle = abs(knobState.deltaAngle)
            let direction: RotationDirection = knobState.deltaAngle >= 0 ? .clockwise : .counterClockwise

            translator.apply(units: deltaAngle, direction: direction)

            let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: radius) }
            overlayController.update(
                angle: currentAngle,
                radius: radius,
                isDeadzone: false,
                isTooClose: false,
                scale: activeBaseScale,
                themeColor: color,
                outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                configType: knob?.configType ?? .single
            )

            self.currentAngle = currentAngle
            previousAngle = currentAngle

            PKLogger.knob.debug("applied delta=\(deltaAngle) dir=\(String(describing: direction)) scale=\(finalScale)")
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

    func resolveThemeColor(for knob: Knob, zoneIndex: Int, radius: Double? = nil) -> String? {
        if knob.configType == .double, let doubleConfig = knob.doubleConfig {
            if zoneIndex == 0 {
                return doubleConfig.inner.themeColor ?? knob.themeColor
            } else if zoneIndex == 1 {
                return doubleConfig.outer.themeColor ?? knob.themeColor
            }
        }
        if knob.configType == .cvk, let cvkConfig = knob.cvkConfig, let r = radius {
            let outerColor = cvkConfig.outerThemeColor ?? knob.themeColor ?? "#FF9F0A"
            let innerColor = cvkConfig.innerThemeColor ?? knob.themeColor ?? "#30D158"
            
            let minR = cvkConfig.minRadius
            let maxR = cvkConfig.maxRadius
            let t: Double
            if r <= minR {
                t = 1.0
            } else if r >= maxR {
                t = 0.0
            } else {
                t = 1.0 - (r - minR) / (maxR - minR)
            }
            return interpolateHexColor(from: outerColor, to: innerColor, t: t)
        }
        return knob.themeColor
    }

    private func interpolateHexColor(from hex1: String, to hex2: String, t: Double) -> String {
        guard let color1 = NSColor(hex: hex1), let color2 = NSColor(hex: hex2) else {
            return hex1
        }
        
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
        color2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)
        
        var h: CGFloat
        if abs(h1 - h2) > 0.5 {
            if h1 > h2 {
                h = h1 + (h2 + 1.0 - h1) * CGFloat(t)
            } else {
                h = h1 - (h1 + 1.0 - h2) * CGFloat(t)
            }
            if h < 0 { h += 1.0 }
            if h > 1 { h -= 1.0 }
        } else {
            h = h1 + (h2 - h1) * CGFloat(t)
        }
        
        let s = s1 + (s2 - s1) * CGFloat(t)
        let b = b1 + (b2 - b1) * CGFloat(t)
        
        let resultColor = NSColor(hue: h, saturation: s, brightness: b, alpha: 1.0)
        return resultColor.toHex() ?? hex1
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
            PKLogger.knob.error("Failed to create event tap")
            showEventTapErrorAlertOnce()
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
            PKLogger.knob.debug("Re-enabled event tap after timeout/disable event")
        }
    }

    private func showEventTapErrorAlertOnce() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        let isTesting = env.keys.contains { $0.range(of: "xctest", options: .caseInsensitive) != nil }
        if isTesting || NSClassFromString("XCTestCase") != nil {
            return
        }
        #endif
        
        guard !hasShownEventTapErrorAlert else { return }
        hasShownEventTapErrorAlert = true
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = String(localized: "eventTap.error.title", defaultValue: "辅助功能与输入监听权限已失效")
            alert.informativeText = String(localized: "eventTap.error.message", defaultValue: "检测到 Event Tap 注册失败。如果您已经授予了权限，这通常是由于重新编译导致 macOS 安全缓存失效引起的。\n\n请在系统设置中，将 PhantomKnob 从【辅助功能】与【输入监听】列表中完全移除（选中并按 - 按钮），然后重新添加即可激活权限。")
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "eventTap.error.openSettings", defaultValue: "打开系统设置"))
            alert.addButton(withTitle: String(localized: "eventTap.error.cancel", defaultValue: "取消"))
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    func handleEventTap(proxy: CGEventTapProxy?, type: CGEventType, event: CGEvent) -> Bool {
        // Skip events posted by our own translators
        let sourceUserData = event.getIntegerValueField(.eventSourceUserData)
        guard sourceUserData != 0xDEADC0DE else { return false }
        
        // Check key events for customization trigger first
        if type == .keyDown || type == .keyUp {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == 8 { // 'C' keycode
                if state.isKnobing || state.isCooling {
                    if type == .keyDown {
                        DispatchQueue.main.async { [weak self] in
                            self?.enterCustomization()
                        }
                    }
                    return true // Swallow both keyDown and keyUp to prevent penetration!
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
                PKLogger.knob.debug("Swallowed gesture event of type: \(typeVal) (knobing: \(self.state.isKnobing), intercepting: \(self.isInterceptingGestures))")
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
        case .cvk:
            defaultBaseScale = 1.0
        }
        
        if let overrideValue = UserDefaults.app.object(forKey: key) as? Double {
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
            UserDefaults.app.set(nextVal, forKey: key)
            self.lastResolvedBaseScale = nextVal
            
            // Post notification for scale updates
            NotificationCenter.default.post(
                name: NSNotification.Name("KnobBaseScaleDidUpdate"),
                object: nil,
                userInfo: ["scale": nextVal]
            )
            
            // Apply immediately to currentTranslator scale
            if let translator = currentTranslator {
                translator.scale = nextVal
            }
            
            // Update Overlay UI immediately
            let knob = KnobCustomizer.shared.knob(for: target.knobKey)
            let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: self.currentRadius) }
            overlayController.update(
                angle: self.currentAngle,
                radius: self.currentRadius,
                isDeadzone: false,
                scale: nextVal,
                themeColor: color,
                outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                configType: knob?.configType ?? .single
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
        
        // 1. 如果命中配置库中的任何自定义或内置配置，说明已为此进行了特化，必然是可调节的
        if KnobCustomizer.shared.knob(for: target.knobKey) != nil {
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

    private func makeTranslator(for target: DetectedTarget, knob: Knob?, radius: Double = 0.0) -> InputTranslator {
        var translation = knob?.translation ?? autoDetectTranslation(for: target)
        var scale = knob?.scaleConfig?.resolve() ?? 1.0
        var isInverted = knob?.invert ?? false

        if let knob = knob {
            switch knob.configType {
            case .single:
                if let single = knob.singleConfig {
                    translation = single.translation
                    scale = single.unitPerDegree
                    let isDefaultCW = (single.clockwiseAction == "arrowUp" || single.clockwiseAction == "arrowRight" || single.clockwiseAction == "scrollUp" || single.clockwiseAction == "swipeUp" || single.clockwiseAction == "swipeRight" || single.clockwiseAction == "increase")
                    isInverted = !isDefaultCW
                }
            case .double:
                if let double = knob.doubleConfig {
                    let isOuter = radius > (double.inner.maxRadius + double.inner.margin)
                    let activeKnob = isOuter ? double.outer : double.inner
                    translation = activeKnob.translation
                    scale = activeKnob.unitPerDegree
                    let isDefaultCW = (activeKnob.clockwiseAction == "arrowUp" || activeKnob.clockwiseAction == "arrowRight" || activeKnob.clockwiseAction == "scrollUp" || activeKnob.clockwiseAction == "swipeUp" || activeKnob.clockwiseAction == "swipeRight" || activeKnob.clockwiseAction == "increase")
                    isInverted = !isDefaultCW
                }
            case .cvk:
                if let cvk = knob.cvkConfig {
                    translation = cvk.translation
                    scale = ScaleResolver.resolveCVK(radius: radius, config: ScaleConfigCVK(minRadius: cvk.minRadius, maxRadius: cvk.maxRadius, minScale: cvk.minScale, maxScale: cvk.maxScale)) ?? cvk.minScale
                    let isDefaultCW = (cvk.clockwiseAction == "arrowUp" || cvk.clockwiseAction == "arrowRight" || cvk.clockwiseAction == "scrollUp" || cvk.clockwiseAction == "swipeUp" || cvk.clockwiseAction == "swipeRight" || cvk.clockwiseAction == "increase")
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

    private func determineTranslation(for target: DetectedTarget, knob: Knob?, radius: Double) -> InputTranslation {
        var translation = knob?.translation ?? autoDetectTranslation(for: target)
        if let knob = knob {
            switch knob.configType {
            case .single:
                if let single = knob.singleConfig {
                    translation = single.translation
                }
            case .double:
                if let double = knob.doubleConfig {
                    let isOuter = radius > (double.inner.maxRadius + double.inner.margin)
                    let activeKnob = isOuter ? double.outer : double.inner
                    translation = activeKnob.translation
                }
            case .cvk:
                if let cvk = knob.cvkConfig {
                    translation = cvk.translation
                }
            }
        }
        return translation
    }

    private func simulateClick(at point: CGPoint) {
        didSimulateClickForTest = true
        PKLogger.knob.debug("Simulating click to focus: \(String(describing: point))")
        let source = CGEventSource(stateID: .privateState)
        source?.userData = 0xDEADC0DE // 携带特殊标记防自身 tap 拦截死循环
        
        let clickPoint: CGPoint
        if let carbonPos = initialTouchPositionCarbon {
            clickPoint = carbonPos
        } else {
            let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
            clickPoint = CGPoint(x: point.x, y: screenHeight - point.y)
        }
        
        guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: clickPoint, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: clickPoint, mouseButton: .left) else {
            return
        }
        
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }

    private func simulateReturnKey() {
        didSimulateReturnForTest = true
        PKLogger.knob.debug("Simulating Return key to release text focus")
        let source = CGEventSource(stateID: .privateState)
        source?.userData = 0xDEADC0DE
        
        let returnKeyCode: CGKeyCode = 36 // Return key
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false) else {
            return
        }
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    static func getActiveWindowPageMode(for bundleID: String) -> String? {
        guard bundleID == "com.blackmagic-design.DaVinciResolve" else { return nil }
        
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard let app = apps.first else { return nil }
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowVal: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &windowVal) == .success,
              let windowElement = windowVal else { return nil }
              
        let axWindow = unsafeBitCast(windowElement, to: AXUIElement.self)
        var titleVal: AnyObject?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleVal) == .success,
              let title = titleVal as? String else { return nil }
              
        return TargetDetector.extractResolvePageMode(from: title)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let hexCleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hexCleaned).scanHexInt64(&int) else { return nil }
        let r, g, b: UInt64
        switch hexCleaned.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0)
    }
}
