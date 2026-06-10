import XCTest
@testable import PhantomKnob

class KnobPanelViewModelTests: XCTestCase {
    func testViewModelHoverAndGestureRouting() {
        let viewModel = ControlPanelViewModel(
            audioService: AudioControlService(),
            brightnessService: DisplayBrightnessService(),
            backlightService: KeyboardBacklightService()
        )
        
        // Initial state should have no focus target
        XCTAssertNil(viewModel.focusedVariable)
        
        // Focus volume
        viewModel.setHoverTarget(.volume)
        XCTAssertEqual(viewModel.focusedVariable, .volume)
        
        // Send a rotation delta (e.g. clockwise 10 degrees) and verify volume changes
        let initialVolume = viewModel.volumeVal
        viewModel.receiveRotationDelta(10.0)
        XCTAssertTrue(viewModel.volumeVal >= initialVolume, "Volume should increase or stay capped at 1.0")
        
        // Unfocus
        viewModel.setHoverTarget(nil)
        XCTAssertNil(viewModel.focusedVariable)
    }
}
