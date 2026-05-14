import SwiftUI
import AppKit

class OverlayController: ObservableObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayView>?
    
    @Published var isVisible: Bool = false
    @Published var targetName: String = ""
    @Published var angle: Double = 0
    @Published var displayValue: String = ""
    
    private var position: CGPoint = .zero
    
    func show(at position: CGPoint, targetName: String, displayValue: String) {
        self.position = position
        self.targetName = targetName
        self.displayValue = displayValue
        
        if panel == nil {
            createPanel()
        }
        
        let screenPosition = convertToScreenCoordinates(position)
        panel?.setFrameOrigin(screenPosition)
        panel?.makeKeyAndOrderFront(nil)
        isVisible = true
    }
    
    func update(angle: Double, displayValue: String) {
        self.angle = angle
        self.displayValue = displayValue
        updateOverlayView()
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }
    
    func fadeOut(duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel?.animator().alphaValue = 0
        } completionHandler: {
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
        
        panel.level = NSWindow.Level.floating
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
        guard let screen = NSScreen.main else { return position }
        let screenHeight = screen.frame.height
        return CGPoint(
            x: position.x - 60,
            y: screenHeight - position.y - 70
        )
    }
}
