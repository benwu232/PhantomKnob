import AppKit
import Foundation

protocol GlobalTouchDelegate: AnyObject {
    func onGlobalTouchesBegan(_ touches: Set<NSTouch>)
    func onGlobalTouchesMoved(_ touches: Set<NSTouch>)
    func onGlobalTouchesEnded(_ touches: Set<NSTouch>)
}

class GlobalTouchHandler {
    weak var delegate: GlobalTouchDelegate?
    
    private var eventMonitor: Any?
    private var isMonitoring = false
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.gesture, .directTouches]
        ) { [weak self] event in
            self?.handleEvent(event)
        }
        
        isMonitoring = true
    }
    
    func stopMonitoring() {
        guard isMonitoring, let monitor = eventMonitor else { return }
        
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
        isMonitoring = false
    }
    
    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .gesture:
            handleGestureEvent(event)
        case .directTouches:
            handleTouchEvent(event)
        default:
            break
        }
    }
    
    private func handleGestureEvent(_ event: NSEvent) {
        switch event.phase {
        case .began:
            if let touches = event.touches(matching: .any, in: nil) as? Set<NSTouch> {
                delegate?.onGlobalTouchesBegan(touches)
            }
        case .changed:
            if let touches = event.touches(matching: .any, in: nil) as? Set<NSTouch> {
                delegate?.onGlobalTouchesMoved(touches)
            }
        case .ended, .cancelled:
            if let touches = event.touches(matching: .any, in: nil) as? Set<NSTouch> {
                delegate?.onGlobalTouchesEnded(touches)
            }
        default:
            break
        }
    }
    
    private func handleTouchEvent(_ event: NSEvent) {
        if let touches = event.touches(matching: .any, in: nil) as? Set<NSTouch> {
            switch event.phase {
            case .began:
                delegate?.onGlobalTouchesBegan(touches)
            case .changed:
                delegate?.onGlobalTouchesMoved(touches)
            case .ended, .cancelled:
                delegate?.onGlobalTouchesEnded(touches)
            default:
                break
            }
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
