import XCTest
@testable import PhantomKnob

class UserGuideViewModelTests: XCTestCase {
    func testUserGuideStepTransitionsAndRotationUnlock() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        XCTAssertEqual(vm.currentStep, 1)
        XCTAssertFalse(vm.isTouchpadDetected)
        
        // Step 1 nextStep is blocked without touchpad detection
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 1)
        
        // Simulate touchpad detection (3 notifications)
        for _ in 1...3 {
            NotificationCenter.default.post(
                name: NSNotification.Name("TouchpadCoordinatesValidated"),
                object: nil,
                userInfo: ["points": [0: CGPoint.zero]]
            )
        }
        XCTAssertTrue(vm.isTouchpadDetected)
        
        // Now nextStep succeeds
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)
        
        // Test Step 2 rotation
        vm.hoveredKnob = .doubleKnob
        vm.registerRotation(20.0)
        XCTAssertEqual(vm.doubleKnobAngle, 20.0)
        XCTAssertEqual(vm.doubleKnobVal, 60.0, accuracy: 0.01) // 50 + (20 * 0.5 * 1.0)
        
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
    
    func testSkipOnNextStartupDefaultsToFalse() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        XCTAssertFalse(vm.skipOnNextStartup)
    }
    
    func testCompleteGuideSavesSkipPreference() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        
        // 1. Test when skipOnNextStartup is true
        vm.skipOnNextStartup = true
        vm.completeGuide()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup"))
        
        // Reset
        UserDefaults.standard.removeObject(forKey: "skipUserGuideOnStartup")
        
        // 2. Test when skipOnNextStartup is false
        vm.skipOnNextStartup = false
        vm.completeGuide()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup"))
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "skipUserGuideOnStartup")
    }
    
    func testTouchpadCoordinatesValidationCounting() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        XCTAssertEqual(vm.touchpadSamplesCount, 0)
        XCTAssertFalse(vm.isTouchpadDetected)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": [0: CGPoint.zero]]
        )
        XCTAssertEqual(vm.touchpadSamplesCount, 1)
        XCTAssertFalse(vm.isTouchpadDetected)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": [0: CGPoint.zero]]
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": [0: CGPoint.zero]]
        )
        XCTAssertEqual(vm.touchpadSamplesCount, 3)
        XCTAssertTrue(vm.isTouchpadDetected)
    }
    
    func testKeyboardMultiplierNotification() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        vm.currentStep = 2
        vm.currentMultiplier = 1.0
        
        NotificationCenter.default.post(
            name: NSNotification.Name("KnobBaseScaleDidUpdate"),
            object: nil,
            userInfo: ["scale": 2.5]
        )
        XCTAssertEqual(vm.currentMultiplier, 2.5)
    }
    
    func testRotationUpdatesDoubleAndLinearKnobsWithMultiplier() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        vm.currentStep = 2
        vm.currentMultiplier = 2.0
        
        // Test Double Knob
        vm.hoveredKnob = .doubleKnob
        vm.registerRotation(10.0)
        XCTAssertEqual(vm.doubleKnobAngle, 10.0)
        XCTAssertEqual(vm.doubleKnobVal, 60.0, accuracy: 0.01) // 50.0 + (10.0 * 0.5 * 2.0)
        
        // Test Linear Knob
        vm.hoveredKnob = .linearKnob
        vm.registerRotation(-20.0)
        XCTAssertEqual(vm.linearKnobAngle, -20.0)
        XCTAssertEqual(vm.linearKnobVal, 30.0, accuracy: 0.01) // 50.0 - (20.0 * 0.5 * 2.0)
    }
    
    func testRadiusBasedBaseMultipliers() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        vm.currentStep = 2
        
        // 模拟双环旋钮内圈半径 (例如 50mm)
        let pointsInner = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 200, y: 100) // 间距 100, 半径 = 50.0
        ]
        vm.hoveredKnob = .doubleKnob
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsInner]
        )
        // Verify doubleKnobBaseMultiplier is set correctly (expect 0.1 because radius <= 65)
        XCTAssertEqual(vm.doubleKnobBaseMultiplier, 0.1, accuracy: 0.01)
        
        // 模拟双环旋钮外圈半径 (例如 80mm)
        let pointsOuter = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 260, y: 100) // 间距 160, 半径 = 80.0
        ]
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsOuter]
        )
        XCTAssertEqual(vm.doubleKnobBaseMultiplier, 1.0, accuracy: 0.01)
        
        // 模拟无极变速旋钮插值 (minR=30 -> 0.1, maxR=100 -> 5.0)
        // 半径 = 65.0 (正好位于 30 和 100 正中间，插值结果为 0.1 + 0.5 * 4.9 = 2.55)
        let pointsMid = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 230, y: 100) // 间距 130, 半径 = 65.0
        ]
        vm.hoveredKnob = .linearKnob
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsMid]
        )
        XCTAssertEqual(vm.linearKnobBaseMultiplier, 2.55, accuracy: 0.05)
    }
}

