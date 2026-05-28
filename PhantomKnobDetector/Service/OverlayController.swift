// PhantomKnobDetector/Service/OverlayController.swift
import SwiftUI
import AppKit

class OverlayController: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayView>?

    @Published var isVisible: Bool = false
    @Published var targetName: String? = nil
    @Published var angle: Double = 0
    @Published var displayValue: String? = nil

    private var position: CGPoint = .zero
    private var showCount: Int = 0 // 递增标记每次显示的代数（Generation Token），用于解决异步竞态问题

    func show(at position: CGPoint, targetName: String?, displayValue: String?) {
        self.position = position
        self.targetName = targetName
        self.displayValue = displayValue

        showCount += 1
        writeDebugLog("[OverlayController] show() called: targetName = \(targetName ?? "nil"), displayValue = \(displayValue ?? "nil"), showCount = \(showCount), position = \(position)")

        if panel == nil {
            createPanel()
        }

        // 显式停止之前的动画并强制恢复不透明度
        panel?.animator().alphaValue = 1.0
        panel?.alphaValue = 1.0

        let screenPosition = convertToScreenCoordinates(position)
        panel?.setFrameOrigin(screenPosition)
        panel?.orderFrontRegardless()
        isVisible = true
    }

    func update(angle: Double, displayValue: String?) {
        self.angle = angle
        self.displayValue = displayValue
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

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 140),
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
            displayValue: displayValue
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
            displayValue: displayValue
        )
    }

    private func convertToScreenCoordinates(_ position: CGPoint) -> CGPoint {
        return CGPoint(
            x: position.x - 60,
            y: position.y - 70
        )
    }
}
