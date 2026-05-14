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
            matching: [.gesture]
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
        default:
            break
        }
    }
    
    private func handleGestureEvent(_ event: NSEvent) {
        switch event.phase {
        case .began:
            let touches = event.touches(matching: .any, in: nil)
            delegate?.onGlobalTouchesBegan(touches)
        case .changed:
            let touches = event.touches(matching: .any, in: nil)
            delegate?.onGlobalTouchesMoved(touches)
        case .ended, .cancelled:
            let touches = event.touches(matching: .any, in: nil)
            delegate?.onGlobalTouchesEnded(touches)
        default:
            break
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
