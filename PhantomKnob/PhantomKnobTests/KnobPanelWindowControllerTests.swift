import XCTest
@testable import PhantomKnob

class KnobPanelWindowControllerTests: XCTestCase {
    private var openControllers: [KnobPanelWindowController] = []
    
    override func tearDown() {
        for controller in openControllers {
            controller.hide()
        }
        openControllers.removeAll()
        super.tearDown()
    }
    
    func testWindowToggle() {
        let controller = KnobPanelWindowController()
        openControllers.append(controller)
        XCTAssertFalse(controller.isVisible)
        
        let expectation = XCTestExpectation(description: "Show and hide window")
        DispatchQueue.main.async {
            controller.show()
            XCTAssertTrue(controller.isVisible)
            
            controller.hide()
            XCTAssertFalse(controller.isVisible)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWindowKeyboardFocusSwitching() {
        let controller = KnobPanelWindowController.shared
        controller.show()
        
        let viewModel = ControlPanelViewModel.shared
        viewModel.focusedVariable = .volume
        
        if let window = controller.window {
            let rightEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 124 // Right arrow
            )
            if let ev = rightEvent {
                window.keyDown(with: ev)
                XCTAssertEqual(viewModel.focusedVariable, .brightness)
            }
            
            let leftEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 123 // Left arrow
            )
            if let ev = leftEvent {
                window.keyDown(with: ev)
                XCTAssertEqual(viewModel.focusedVariable, .volume)
            }
        }
        controller.hide()
    }
    
    func testWindowScrollWheelSwipeFocusSwitching() {
        let controller = KnobPanelWindowController.shared
        controller.show()
        
        let viewModel = ControlPanelViewModel.shared
        viewModel.focusedVariable = .volume
        
        if let window = controller.window as? KnobPanelWindow {
            // 模拟退化防抖时间逻辑：第一次右滑 (deltaX: 5.0)
            window.handleScrollWheelGesture(phase: [], momentumPhase: [], deltaX: 5.0, deltaY: 0.0, systemTime: 1000.0)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            // 模拟退化防抖时间逻辑：0.2s 后左滑 (不足 0.4s，被防抖拦截)
            // 1000.2 - 1000.0 = 0.2s，不满足。所以不应该被触发切换，仍为 brightness
            window.handleScrollWheelGesture(phase: [], momentumPhase: [], deltaX: -5.0, deltaY: 0.0, systemTime: 1000.2)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            // 模拟退化防抖时间逻辑：0.5s 后左滑 (超过 0.4s，允许触发)
            window.handleScrollWheelGesture(phase: [], momentumPhase: [], deltaX: -5.0, deltaY: 0.0, systemTime: 1000.7)
            XCTAssertEqual(viewModel.focusedVariable, .volume)
        }
        controller.hide()
    }
    
    func testWindowScrollWheelGestureLifecycleAndMomentum() {
        let controller = KnobPanelWindowController.shared
        controller.show()
        
        let viewModel = ControlPanelViewModel.shared
        viewModel.focusedVariable = .volume
        
        if let window = controller.window as? KnobPanelWindow {
            // 测试场景 1：一次完整的手势滑动，多次事件只触发一次切换
            // 第一步：.began 阶段，deltaX 较小，不触发切换
            window.handleScrollWheelGesture(phase: .began, momentumPhase: [], deltaX: 0.5, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .volume)
            
            // 第二步：.changed 阶段，deltaX 大于阈值，触发切换到 brightness
            window.handleScrollWheelGesture(phase: .changed, momentumPhase: [], deltaX: 4.0, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            // 第三步：.changed 阶段，又来了一个大 deltaX 事件，但不应再次触发切换（锁定了）
            window.handleScrollWheelGesture(phase: .changed, momentumPhase: [], deltaX: 5.0, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            // 第四步：.ended 阶段，deltaX 变小 (0.1)，重置锁定状态
            window.handleScrollWheelGesture(phase: .ended, momentumPhase: [], deltaX: 0.1, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            // 测试场景 2：紧接着惯性滚动阶段，delta 很大，但不应触发切换
            window.handleScrollWheelGesture(phase: [], momentumPhase: .began, deltaX: 4.5, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            window.handleScrollWheelGesture(phase: [], momentumPhase: .changed, deltaX: 5.0, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            window.handleScrollWheelGesture(phase: [], momentumPhase: .ended, deltaX: 0.5, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .brightness)
            
            // 测试场景 3：下一次新滑动手势开始，左滑
            window.handleScrollWheelGesture(phase: .began, momentumPhase: [], deltaX: -0.5, deltaY: 0.0)
            window.handleScrollWheelGesture(phase: .changed, momentumPhase: [], deltaX: -4.0, deltaY: 0.0)
            XCTAssertEqual(viewModel.focusedVariable, .volume)
            window.handleScrollWheelGesture(phase: .ended, momentumPhase: [], deltaX: -0.1, deltaY: 0.0)
        }
        controller.hide()
    }
}
