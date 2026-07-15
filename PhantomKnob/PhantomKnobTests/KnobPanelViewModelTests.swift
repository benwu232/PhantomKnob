import XCTest
@testable import PhantomKnob

class KnobPanelViewModelTests: XCTestCase {
    func testViewModelHoverAndGestureRouting() {
        let viewModel = ControlPanelViewModel(
            audioService: AudioControlService(),
            brightnessService: DisplayBrightnessService(),
            backlightService: KeyboardBacklightService()
        )
        
        // Initial state should have default focus target: volume
        XCTAssertEqual(viewModel.focusedVariable, .volume)
        
        // Focus volume
        viewModel.setHoverTarget(.volume)
        XCTAssertEqual(viewModel.focusedVariable, .volume)
        
        // Send a rotation delta (e.g. clockwise 10 degrees) and verify volume changes
        let initialVolume = viewModel.volumeVal
        viewModel.receiveRotationDelta(10.0)
        XCTAssertTrue(viewModel.volumeVal >= initialVolume, "Volume should increase or stay capped at 1.0")
        
        // Unfocus (should NOT clear focus target now)
        viewModel.setHoverTarget(nil)
        XCTAssertEqual(viewModel.focusedVariable, .volume)
    }
    
    func testMinimalKnobPanelInteraction() {
        let viewModel = ControlPanelViewModel()
        
        // 默认聚焦应为 volume
        XCTAssertEqual(viewModel.focusedVariable, .volume)
        
        // selectNextVariable 应该切换到 brightness
        viewModel.selectNextVariable()
        XCTAssertEqual(viewModel.focusedVariable, .brightness)
        
        // selectNextVariable 应该切换到 keyboardBacklight
        viewModel.selectNextVariable()
        XCTAssertEqual(viewModel.focusedVariable, .keyboardBacklight)
        
        // selectNextVariable 应该回到 volume
        viewModel.selectNextVariable()
        XCTAssertEqual(viewModel.focusedVariable, .volume)
        
        // selectPrevVariable 应该切换到 keyboardBacklight
        viewModel.selectPrevVariable()
        XCTAssertEqual(viewModel.focusedVariable, .keyboardBacklight)
        
        // setHoverTarget 非 nil 应更新焦点
        viewModel.setHoverTarget(.brightness)
        XCTAssertEqual(viewModel.focusedVariable, .brightness)
        
        // setHoverTarget 传入 nil 应该不清除焦点 (仍为 brightness)
        viewModel.setHoverTarget(nil)
        XCTAssertEqual(viewModel.focusedVariable, .brightness)
    }
}
