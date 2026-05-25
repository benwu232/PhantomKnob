import AppKit
import Foundation

protocol GlobalTouchDelegate: AnyObject {
    func onGlobalScroll(phase: NSEvent.Phase, deltaX: CGFloat, deltaY: CGFloat)
    func onGlobalModifierOptionChanged(isPressed: Bool)
}

class GlobalTouchHandler {
    weak var delegate: GlobalTouchDelegate?
    
    private var eventMonitor: Any?
    private var isMonitoring = false
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // 全局注册：仅监听合规的鼠标滚动及键盘修饰键变更
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.scrollWheel, .flagsChanged]
        ) { [weak self] event in
            self?.handleEvent(event)
        }
        
        isMonitoring = true
        writeDebugLog("[GlobalTouchHandler] Standard global event tap started successfully")
    }
    
    func stopMonitoring() {
        guard isMonitoring, let monitor = eventMonitor else { return }
        
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
        isMonitoring = false
        writeDebugLog("[GlobalTouchHandler] Standard global event tap stopped")
    }
    
    private func handleEvent(_ event: NSEvent) {
        if event.type == .scrollWheel {
            // 分发标准滚动事件（用于常规的滑块侦测与备用调节）
            delegate?.onGlobalScroll(phase: event.phase, deltaX: event.deltaX, deltaY: event.deltaY)
        } else if event.type == .flagsChanged {
            // 检测全局 Option 键的状态（.option 的 flagsChanged 会更改 flags）
            let isOptionPressed = event.modifierFlags.contains(.option)
            delegate?.onGlobalModifierOptionChanged(isPressed: isOptionPressed)
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
