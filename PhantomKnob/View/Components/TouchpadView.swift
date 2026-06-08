import AppKit
import SwiftUI

class TouchpadView: NSView {
    weak var touchDelegate: TouchpadEventDelegate?
    
    // Debug: throttling for touchesMoved
    private var lastMovedPrintTime: Date?
    private let movedPrintInterval: TimeInterval = 0.5
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        acceptsTouchEvents = true
        wantsRestingTouches = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        acceptsTouchEvents = true
        wantsRestingTouches = true
    }
    
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        printTouchCoordinates(touches, event: "touchesBegan")
        touchDelegate?.onTouchesBegan(touches)
    }
    
    override func touchesMoved(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        
        // Debug: throttle to print once every 0.5 seconds
        let now = Date()
        if let lastTime = lastMovedPrintTime {
            if now.timeIntervalSince(lastTime) >= movedPrintInterval {
                printTouchCoordinates(touches, event: "touchesMoved")
                lastMovedPrintTime = now
            }
        } else {
            printTouchCoordinates(touches, event: "touchesMoved")
            lastMovedPrintTime = now
        }
        
        touchDelegate?.onTouchesMoved(touches)
    }
    
    override func touchesEnded(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        printTouchCoordinates(touches, event: "touchesEnded")
        touchDelegate?.onTouchesEnded(touches)
    }
    
    override func touchesCancelled(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesEnded(touches)
    }
    
    // MARK: - Debug Helpers
    
    private func printTouchCoordinates(_ touches: Set<NSTouch>, event: String) {
        guard !touches.isEmpty else { return }
        
        var normCoords: [(x: Double, y: Double)] = []
        
        for touch in touches {
            let norm = touch.normalizedPosition
            normCoords.append((x: norm.x, y: norm.y))
        }
        
        let normStr = normCoords.map { String(format: "(%.2f, %.2f)", $0.x, $0.y) }.joined(separator: ", ")
        
        print("\(event): norm=[\(normStr)]")
    }
}

struct TouchpadViewWrapper: NSViewRepresentable {
    let delegate: TouchpadEventDelegate
    
    func makeNSView(context: Context) -> TouchpadView {
        let view = TouchpadView()
        view.touchDelegate = delegate
        return view
    }
    
    func updateNSView(_ nsView: TouchpadView, context: Context) {
        nsView.touchDelegate = delegate
    }
}
