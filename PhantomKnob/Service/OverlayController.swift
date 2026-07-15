// PhantomKnob/Service/OverlayController.swift
import SwiftUI
import AppKit
import os

class OverlayController: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayView>?

    @Published var isVisible: Bool = false
    @Published var targetName: String? = nil
    @Published var angle: Double = 0
    @Published var isDeadzone: Bool = false
    @Published var scale: Double? = nil
    @Published var themeColor: String = "#0A84FF"
    @Published var overlayStyle: String = "hud"
    @Published var rotationStyle: String = "ticks"
    @Published var diameter: CGFloat = 80.0
    @Published var outerThemeColor: String? = nil
    @Published var innerThemeColor: String? = nil
    @Published var configType: KnobConfigType = .single

    private var position: CGPoint = .zero
    private var showCount: Int = 0 // 递增标记每次显示的代数（Generation Token），用于解决异步竞态问题
    var fixedCenter: CGPoint = .zero

    private let featureGate: FeatureGate

    init(featureGate: FeatureGate = .shared) {
        self.featureGate = featureGate
    }

    deinit {
        if let p = panel {
            DispatchQueue.main.async {
                p.orderOut(nil)
            }
        }
    }

    func show(at position: CGPoint, 
              targetName: String?, 
              scale: Double? = nil, 
              themeColor: String? = nil, 
              overlayStyle: String? = nil, 
              rotationStyle: String? = nil,
              outerThemeColor: String? = nil,
              innerThemeColor: String? = nil,
              configType: KnobConfigType = .single) {
        self.position = position
        self.targetName = targetName
        self.scale = scale
        self.configType = configType
        if !featureGate.hasStyleCustomization {
            self.themeColor = "#8E8E93"
            self.outerThemeColor = nil
            self.innerThemeColor = nil
            self.overlayStyle = "hud"
            self.rotationStyle = "ticks"
        } else {
            self.themeColor = themeColor ?? AppSettings.shared.defaultThemeColor
            self.outerThemeColor = outerThemeColor
            self.innerThemeColor = innerThemeColor
            self.overlayStyle = overlayStyle ?? AppSettings.shared.defaultOverlayStyle
            self.rotationStyle = rotationStyle ?? AppSettings.shared.defaultRotationStyle
        }
        self.diameter = 80.0 // 默认直径 (16mm * 5px/mm)

        let activeScreen = NSScreen.screens.first { $0.frame.contains(position) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = activeScreen.visibleFrame
        let maxD: CGFloat = 300.0
        let centerOffset: CGFloat = 105.0 // 15.0 + 150.0 * 0.6
        
        let candidates: [CGPoint] = [
            CGPoint(x: position.x + centerOffset, y: position.y - centerOffset), // 右下
            CGPoint(x: position.x + centerOffset, y: position.y + centerOffset), // 右上
            CGPoint(x: position.x - centerOffset, y: position.y - centerOffset), // 左下
            CGPoint(x: position.x - centerOffset, y: position.y + centerOffset)  // 左上
        ]
        
        var chosenCenter = candidates[0]
        var found = false
        for center in candidates {
            let rect = NSRect(
                x: center.x - maxD / 2,
                y: center.y - maxD / 2,
                width: maxD,
                height: maxD + 20.0
            )
            if visibleFrame.contains(rect) {
                chosenCenter = center
                found = true
                break
            }
        }
        
        if !found {
            let halfMaxD = maxD / 2
            let minX = visibleFrame.minX + halfMaxD
            let maxX = visibleFrame.maxX - halfMaxD
            let minY = visibleFrame.minY + halfMaxD
            let maxY = visibleFrame.maxY - (halfMaxD + 20.0)
            
            let clampedX = min(max(chosenCenter.x, minX), maxX)
            let clampedY = min(max(chosenCenter.y, minY), maxY)
            chosenCenter = CGPoint(x: clampedX, y: clampedY)
        }
        
        self.fixedCenter = chosenCenter

        showCount += 1
        PKLogger.overlay.debug("show() called: targetName = \(String(describing: targetName)), scale = \(self.scale ?? 0.0), showCount = \(self.showCount), position = \(String(describing: self.position)), fixedCenter = \(String(describing: self.fixedCenter))")

        if panel == nil {
            createPanel()
        }

        // 显式停止之前的动画并强制恢复不透明度
        panel?.animator().alphaValue = 1.0
        panel?.alphaValue = 1.0

        updatePanelFrame()
        panel?.orderFrontRegardless()
        isVisible = true
    }

    func update(angle: Double, 
                radius: Double, 
                isDeadzone: Bool = false, 
                scale: Double? = nil, 
                themeColor: String? = nil,
                outerThemeColor: String? = nil,
                innerThemeColor: String? = nil,
                configType: KnobConfigType = .single) {
        self.angle = angle
        self.isDeadzone = isDeadzone
        self.scale = scale
        self.configType = configType
        if !featureGate.hasStyleCustomization {
            self.themeColor = "#8E8E93"
            self.outerThemeColor = nil
            self.innerThemeColor = nil
        } else {
            if let themeColor = themeColor {
                self.themeColor = themeColor
            }
            self.outerThemeColor = outerThemeColor
            self.innerThemeColor = innerThemeColor
        }
        self.diameter = Self.calculateDiameter(for: radius)
        
        updatePanelFrame()
        updateOverlayView()
    }

    func keepVisible() {
        showCount += 1 // 递增代数打断任何淡出完成的回调
        panel?.animator().alphaValue = 1.0
        panel?.alphaValue = 1.0
        isVisible = true
    }

    func hide() {
        PKLogger.overlay.debug("hide() called: ordering panel out, isVisible was \(self.isVisible)")
        panel?.orderOut(nil)
        isVisible = false
    }

    func fadeOut(duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        let currentGeneration = showCount // 捕获开启淡出时的代数标记
        PKLogger.overlay.debug("fadeOut() initiated: duration = \(duration), currentGeneration = \(currentGeneration)")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.allowsImplicitAnimation = true // 🌟 必须开启隐式动画以确保 NSWindow/NSPanel 动画正常运转且回调 100% 触发
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self = self else { return }

            // 竞态校验：如果在淡出期间或之后，开启了新的手势周期（showCount 发生变更），
            // 则说明新 Overlay 已经激活，必须立刻跳过隐藏逻辑，防止误关新界面的 Bug！
            guard self.showCount == currentGeneration else {
                PKLogger.overlay.debug("fadeOut aborted: new gesture session detected (showCount changed from \(currentGeneration) to \(self.showCount))")
                return
            }

            PKLogger.overlay.debug("fadeOut completed successfully: calling hide() for generation \(currentGeneration)")
            self.hide()
            self.panel?.alphaValue = 1
            completion?()
        }
    }

    private func updatePanelFrame() {
        guard let panel = panel else { return }
        
        let targetFrame = NSRect(
            x: fixedCenter.x - diameter / 2,
            y: fixedCenter.y - diameter / 2,
            width: diameter,
            height: diameter + 20.0
        )
        
        panel.setFrame(targetFrame, display: true)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: diameter, height: diameter + 20.0),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = NSWindow.Level.statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false

        let view = NSHostingView(rootView: OverlayView(
            targetName: targetName,
            angle: angle,
            isDeadzone: isDeadzone,
            scale: scale,
            themeColorHex: themeColor,
            overlayStyle: overlayStyle,
            rotationStyle: rotationStyle,
            diameter: diameter,
            outerThemeColorHex: outerThemeColor,
            innerThemeColorHex: innerThemeColor,
            configType: configType
        ))

        panel.contentView = view
        self.panel = panel
        self.hostingView = view
    }

    private func updateOverlayView() {
        guard let hostingView = hostingView else { return }
        hostingView.rootView = OverlayView(
            targetName: targetName,
            angle: angle,
            isDeadzone: isDeadzone,
            scale: scale,
            themeColorHex: themeColor,
            overlayStyle: overlayStyle,
            rotationStyle: rotationStyle,
            diameter: diameter,
            outerThemeColorHex: outerThemeColor,
            innerThemeColorHex: innerThemeColor,
            configType: configType
        )
    }

    private func convertToScreenCoordinates(_ position: CGPoint) -> CGPoint {
        return CGPoint(
            x: position.x - 60,
            y: position.y - 70
        )
    }

    static func calculateDiameter(for radius: Double) -> CGFloat {
        let raw = CGFloat(radius * 2.0 * 5.0)
        return min(max(raw, 40.0), 300.0)
    }

    static func calculateBestFrame(cursor: CGPoint, diameter: CGFloat, visibleFrame: NSRect) -> NSRect {
        let maxD: CGFloat = 300.0
        let centerOffset: CGFloat = 105.0 // 15 + 150 * 0.6
        
        let candidates: [CGPoint] = [
            CGPoint(x: cursor.x + centerOffset, y: cursor.y - centerOffset),
            CGPoint(x: cursor.x + centerOffset, y: cursor.y + centerOffset),
            CGPoint(x: cursor.x - centerOffset, y: cursor.y - centerOffset),
            CGPoint(x: cursor.x - centerOffset, y: cursor.y + centerOffset)
        ]
        
        var chosenCenter = candidates[0]
        var found = false
        for center in candidates {
            let rect = NSRect(
                x: center.x - maxD / 2,
                y: center.y - maxD / 2,
                width: maxD,
                height: maxD + 20.0
            )
            if visibleFrame.contains(rect) {
                chosenCenter = center
                found = true
                break
            }
        }
        
        if !found {
            let halfMaxD = maxD / 2
            let minX = visibleFrame.minX + halfMaxD
            let maxX = visibleFrame.maxX - halfMaxD
            let minY = visibleFrame.minY + halfMaxD
            let maxY = visibleFrame.maxY - (halfMaxD + 20.0)
            
            let clampedX = min(max(chosenCenter.x, minX), maxX)
            let clampedY = min(max(chosenCenter.y, minY), maxY)
            chosenCenter = CGPoint(x: clampedX, y: clampedY)
        }
        
        return NSRect(
            x: chosenCenter.x - diameter / 2,
            y: chosenCenter.y - diameter / 2,
            width: diameter,
            height: diameter + 20.0
        )
    }
}
