import XCTest
@testable import PhantomKnob

class UserGuideViewModelTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        UserDefaults.standard.removeObject(forKey: "userGuideTouchpadPracticed")
        UserDefaults.standard.removeObject(forKey: "skipUserGuideOnStartup")
        UserDefaults.standard.removeObject(forKey: "firstRunUserGuideCompleted")
        UserDefaults.standard.removeObject(forKey: "firstRunTutorialCompleted")
    }
    
    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "userGuideTouchpadPracticed")
        UserDefaults.standard.removeObject(forKey: "skipUserGuideOnStartup")
        UserDefaults.standard.removeObject(forKey: "firstRunUserGuideCompleted")
        UserDefaults.standard.removeObject(forKey: "firstRunTutorialCompleted")
        try super.tearDownWithError()
    }

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
        XCTAssertEqual(vm.doubleKnobAngle, -20.0)
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
        
        let expectation = XCTestExpectation(description: "isGestureActive becomes true")
        let cancellable = vm.$isGestureActive
            .dropFirst()
            .sink { active in
                if active {
                    expectation.fulfill()
                }
            }
        
        ControlPanelViewModel.shared.isGestureActive = true
        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
        
        let expectation2 = XCTestExpectation(description: "isGestureActive becomes false")
        let cancellable2 = vm.$isGestureActive
            .sink { active in
                if !active {
                    expectation2.fulfill()
                }
            }
        ControlPanelViewModel.shared.isGestureActive = false
        wait(for: [expectation2], timeout: 5.0)
        cancellable2.cancel()
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
        XCTAssertEqual(vm.doubleKnobAngle, -10.0)
        XCTAssertEqual(vm.doubleKnobVal, 60.0, accuracy: 0.01) // 50.0 + (10.0 * 0.5 * 2.0)
        
        // Test Linear Knob
        vm.hoveredKnob = .linearKnob
        vm.registerRotation(-20.0)
        XCTAssertEqual(vm.linearKnobAngle, 20.0)
        XCTAssertEqual(vm.linearKnobVal, 30.0, accuracy: 0.01) // 50.0 - (20.0 * 0.5 * 2.0)
    }
    
    func testRadiusBasedBaseMultipliers() {
        let vm = UserGuideViewModel(audioService: AudioControlService())
        vm.currentStep = 2
        
        let doubleKey = RuleKey(bundleID: "com.phantomknob.controlpanel", axRole: "ControlPanel", identifier: "DoubleKnob")
        let doubleConfig = RuleLibrary.shared.lookup(for: doubleKey)?.doubleConfig
        let maxInner = doubleConfig?.inner.maxRadius ?? 25.0
        let minR_double = doubleConfig?.inner.minRadius ?? 15.0
        let maxR_double = doubleConfig?.outer.maxRadius ?? 60.0
        let scaleInner = doubleConfig?.inner.unitPerDegree ?? 1.0
        let scaleOuter = doubleConfig?.outer.unitPerDegree ?? 0.1
        
        // 模拟双环旋钮内圈半径 (例如 20mm)
        let pointsInner = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 140, y: 100) // 间距 40, 半径 = 20.0
        ]
        vm.hoveredKnob = .doubleKnob
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsInner]
        )
        
        let expectedScaleInner = (20.0 > maxInner) ? scaleOuter : scaleInner
        let expectedDiameterInner = OverlayController.calculateDiameter(for: 20.0)
        XCTAssertEqual(vm.doubleKnobBaseMultiplier, expectedScaleInner, accuracy: 0.01)
        XCTAssertEqual(vm.doubleKnobDiameter, expectedDiameterInner, accuracy: 0.05)
        
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
        
        let expectedScaleOuter = (80.0 > maxInner) ? scaleOuter : scaleInner
        let expectedDiameterOuter = OverlayController.calculateDiameter(for: 80.0)
        XCTAssertEqual(vm.doubleKnobBaseMultiplier, expectedScaleOuter, accuracy: 0.01)
        XCTAssertEqual(vm.doubleKnobDiameter, expectedDiameterOuter, accuracy: 0.05)
        
        // 模拟无极变速旋钮插值
        let linearKey = RuleKey(bundleID: "com.phantomknob.controlpanel", axRole: "ControlPanel", identifier: "LinearKnob")
        let linearConfig = RuleLibrary.shared.lookup(for: linearKey)?.linearConfig
        let minR = linearConfig?.minRadius ?? 10.0
        let maxR = linearConfig?.maxRadius ?? 30.0
        let minScale = linearConfig?.minScale ?? 0.1
        let maxScale = linearConfig?.maxScale ?? 5.0
        
        let pointsMid = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 140, y: 100) // 间距 40, 半径 = 20.0
        ]
        vm.hoveredKnob = .linearKnob
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsMid]
        )
        
        let expectedRatio = (20.0 - minR) / (maxR - minR)
        let expectedMultiplier = maxScale - expectedRatio * (maxScale - minScale)
        let expectedDiameter = OverlayController.calculateDiameter(for: 20.0)
        
        XCTAssertEqual(vm.linearKnobBaseMultiplier, expectedMultiplier, accuracy: 0.05)
        XCTAssertEqual(vm.linearKnobDiameter, expectedDiameter, accuracy: 0.05)
        
        // Hover out resets diameter to 120
        vm.hoveredKnob = .none
        XCTAssertEqual(vm.doubleKnobDiameter, 120.0)
        XCTAssertEqual(vm.linearKnobDiameter, 120.0)
    }
}

