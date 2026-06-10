import XCTest
@testable import PhantomKnob

class UserGuideViewModelTests: XCTestCase {
    func testUserGuideStepTransitionsAndRotationUnlock() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        XCTAssertEqual(vm.currentStep, 1)
        
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)
        XCTAssertFalse(vm.isStep2Unlocked)
        XCTAssertEqual(vm.accumulatedRotation, 0.0)
        
        // 模拟旋转 60.5°
        vm.registerRotation(60.5)
        XCTAssertFalse(vm.isStep2Unlocked)
        XCTAssertEqual(vm.accumulatedRotation, 60.5)
        
        // 模拟旋转 40.0° (累计 100.5°)
        vm.registerRotation(40.0)
        XCTAssertTrue(vm.isStep2Unlocked)
        XCTAssertEqual(vm.accumulatedRotation, 100.5)
        
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 3)
    }
    
    func testTickSoundAccumulation() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        XCTAssertEqual(vm.getTickAccumulator(), 0.0)
        
        // 累计不到 1°，不触发 Tick 消费
        let ticksPlayed1 = vm.updateTickAccumulationAndGetTicks(0.8)
        XCTAssertEqual(ticksPlayed1, 0)
        XCTAssertEqual(vm.getTickAccumulator(), 0.8)
        
        // 累计超过 1° (0.8 + 1.4 = 2.2)，触发 2 次 Tick，剩余 0.2
        let ticksPlayed2 = vm.updateTickAccumulationAndGetTicks(1.4)
        XCTAssertEqual(ticksPlayed2, 2)
        XCTAssertEqual(vm.getTickAccumulator(), 0.20, accuracy: 0.01)
    }
    
    func testGestureActiveBinding() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        XCTAssertFalse(vm.isGestureActive)
        
        // Simulating gesture activate
        ControlPanelViewModel.shared.isGestureActive = true
        
        let expectation = XCTestExpectation(description: "Wait for published value update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(vm.isGestureActive)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Simulating gesture deactivate
        ControlPanelViewModel.shared.isGestureActive = false
        
        let expectation2 = XCTestExpectation(description: "Wait for published value update 2")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(vm.isGestureActive)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
    }
}
