// PhantomKnobDetector/Service/OverlayController.swift
import SwiftUI
import AppKit

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

    private var position: CGPoint = .zero
    private var showCount: Int = 0 // 递增标记每次显示的代数（Generation Token），用于解决异步竞态问题

    func show(at position: CGPoint, 
              targetName: String?, 
              scale: Double? = nil, 
              themeColor: String? = nil, 
              overlayStyle: String? = nil, 
              rotationStyle: String? = nil) {
        self.position = position
        self.targetName = targetName
        self.scale = scale
        self.themeColor = themeColor ?? AppSettings.shared.defaultThemeColor
        self.overlayStyle = overlayStyle ?? AppSettings.shared.defaultOverlayStyle
        self.rotationStyle = rotationStyle ?? AppSettings.shared.defaultRotationStyle
        self.diameter = 80.0 // 默认直径 (16mm * 5px/mm)

        showCount += 1
        writeDebugLog("[OverlayController] show() called: targetName = \(targetName ?? "nil"), scale = \(scale ?? 0.0), showCount = \(showCount), position = \(position)")

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

    func update(angle: Double, radius: Double, isDeadzone: Bool = false, scale: Double? = nil) {
        self.angle = angle
        self.isDeadzone = isDeadzone
        self.scale = scale
        self.diameter = Self.calculateDiameter(for: radius)
        
        updatePanelFrame()
        updateOverlayView()
    }

    func hide() {
        writeDebugLog("[OverlayController] hide() called: ordering panel out, isVisible was \(isVisible)")
        panel?.orderOut(nil)
        isVisible = false
    }

    func fadeOut(duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        let currentGeneration = showCount // 捕获开启淡出时的代数标记
        writeDebugLog("[OverlayController] fadeOut() initiated: duration = \(duration), currentGeneration = \(currentGeneration)")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.allowsImplicitAnimation = true // 🌟 必须开启隐式动画以确保 NSWindow/NSPanel 动画正常运转且回调 100% 触发
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self = self else { return }

            // 竞态校验：如果在淡出期间或之后，开启了新的手势周期（showCount 发生变更），
            // 则说明新 Overlay 已经激活，必须立刻跳过隐藏逻辑，防止误关新界面的 Bug！
            guard self.showCount == currentGeneration else {
                writeDebugLog("[OverlayController] fadeOut aborted: new gesture session detected (showCount changed from \(currentGeneration) to \(self.showCount))")
                return
            }

            writeDebugLog("[OverlayController] fadeOut completed successfully: calling hide() for generation \(currentGeneration)")
            self.hide()
            self.panel?.alphaValue = 1
            completion?()
        }
    }

    private func updatePanelFrame() {
        guard let panel = panel else { return }
        
        let cursorPt = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { $0.frame.contains(cursorPt) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = activeScreen.visibleFrame
        
        let targetFrame = Self.calculateBestFrame(
            cursor: cursorPt,
            diameter: diameter,
            visibleFrame: visibleFrame
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
            diameter: diameter
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
            diameter: diameter
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
        let offset: CGFloat = 15.0
        let w = diameter
        let h = diameter + 20.0
        
        let candidates: [CGPoint] = [
            // 1. 右下 (Bottom-Right)
            CGPoint(x: cursor.x + offset, y: cursor.y - offset - h),
            // 2. 右上 (Top-Right)
            CGPoint(x: cursor.x + offset, y: cursor.y + offset),
            // 3. 左下 (Bottom-Left)
            CGPoint(x: cursor.x - offset - w, y: cursor.y - offset - h),
            // 4. 左上 (Top-Left)
            CGPoint(x: cursor.x - offset - w, y: cursor.y + offset)
        ]
        
        for origin in candidates {
            let rect = NSRect(origin: origin, size: CGSize(width: w, height: h))
            if visibleFrame.contains(rect) {
                return rect
            }
        }
        
        // Fallback: 使用右下，并进行屏幕边缘夹紧 (Clamp)
        let rawOrigin = candidates[0]
        let clampedX = min(max(rawOrigin.x, visibleFrame.minX), visibleFrame.maxX - w)
        let clampedY = min(max(rawOrigin.y, visibleFrame.minY), visibleFrame.maxY - h)
        return NSRect(x: clampedX, y: clampedY, width: w, height: h)
    }
}
