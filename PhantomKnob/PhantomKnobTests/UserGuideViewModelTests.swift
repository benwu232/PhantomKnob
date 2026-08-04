import XCTest

@testable import PhantomKnob

class MockAudioControlService: AudioControlService {
    var mockVolume: Float = 0.5
    
    override func getVolume() -> Float? {
        return mockVolume
    }
    
    override func setVolume(_ volume: Float) -> Bool {
        mockVolume = max(0.0, min(1.0, volume))
        return true
    }
}

class UserGuideViewModelTests: XCTestCase {
    private let suiteName = "com.phantomknob.PhantomKnobTests"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        UserDefaults.app = UserDefaults(suiteName: suiteName) ?? .standard
        UserDefaults.app.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        UserDefaults.app = .standard
        try super.tearDownWithError()
    }

    func testUserGuideStepTransitionsAndRotationUnlock() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        XCTAssertEqual(vm.currentStep, 1)
        XCTAssertFalse(vm.isTouchpadDetected)

        // Step 1 Welcome page -> nextStep should succeed immediately to Step 2
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)

        // Step 2 nextStep is blocked without touchpad detection
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)

        // Simulate touchpad touch coordinates (samples count increments)
        for _ in 1...3 {
            NotificationCenter.default.post(
                name: NSNotification.Name("TouchpadCoordinatesValidated"),
                object: nil,
                userInfo: ["points": [0: CGPoint.zero]]
            )
        }
        // Touch alone should NOT unlock step 2
        XCTAssertFalse(vm.isTouchpadDetected)

        // Simulate rotation to 30 degrees while hovered
        vm.hovered = true
        vm.registerRotation(30.0)
        XCTAssertTrue(vm.isTouchpadDetected)

        // Now nextStep succeeds to Step 3
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 3)

        // Test Step 3 rotation
        vm.hoveredKnob = .doubleKnob
        vm.registerRotation(20.0)
        XCTAssertEqual(vm.doubleKnobAngle, -20.0)
        XCTAssertEqual(vm.doubleKnobVal, 60.0, accuracy: 0.01)  // 50 + (20 * 0.5 * 1.0)

        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 4)
    }

    func testFiveStepTransitionsAndTargetStepReset() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        XCTAssertEqual(vm.currentStep, 1)

        // Step 1 -> Step 2
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)

        // Step 2 -> Step 2 (blocked)
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)

        // Unblock Step 2
        vm.isTouchpadDetected = true
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 3)

        // Step 3 -> Step 4
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 4)

        // Step 4 -> Step 5
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 5)

        // Reset to Step 5 via notification
        UserGuideWindowController.shared.initialStep = 5
        NotificationCenter.default.post(name: NSNotification.Name("UserGuideWindowDidShow"), object: nil)
        XCTAssertEqual(vm.currentStep, 5)
    }

    func testTickSoundAccumulation() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
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
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
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
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        XCTAssertFalse(vm.skipOnNextStartup)
    }

    func testCompleteGuideSavesSkipPreference() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())

        // 1. Test when skipOnNextStartup is true
        vm.skipOnNextStartup = true
        vm.completeGuide()
        XCTAssertTrue(UserDefaults.app.bool(forKey: "skipUserGuideOnStartup"))

        // Reset
        UserDefaults.app.removeObject(forKey: "skipUserGuideOnStartup")

        // 2. Test when skipOnNextStartup is false
        vm.skipOnNextStartup = false
        vm.completeGuide()
        XCTAssertFalse(UserDefaults.app.bool(forKey: "skipUserGuideOnStartup"))

        // Clean up
        UserDefaults.app.removeObject(forKey: "skipUserGuideOnStartup")
    }

    func testTouchpadCoordinatesValidationCounting() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        vm.currentStep = 2
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
        XCTAssertFalse(vm.isTouchpadDetected)
    }

    func testKeyboardMultiplierNotification() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        vm.currentStep = 3
        vm.currentMultiplier = 1.0

        NotificationCenter.default.post(
            name: NSNotification.Name("KnobBaseScaleDidUpdate"),
            object: nil,
            userInfo: ["scale": 2.5]
        )
        XCTAssertEqual(vm.currentMultiplier, 2.5)
    }

    func testRotationUpdatesDoubleAndCVKKnobsWithMultiplier() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        vm.currentStep = 3
        vm.currentMultiplier = 2.0

        // Test Double Knob
        vm.hoveredKnob = .doubleKnob
        vm.registerRotation(10.0)
        XCTAssertEqual(vm.doubleKnobAngle, -10.0)
        XCTAssertEqual(vm.doubleKnobVal, 60.0, accuracy: 0.01)  // 50.0 + (10.0 * 0.5 * 2.0)

        // Test Linear Knob
        vm.hoveredKnob = .cvkKnob
        vm.registerRotation(-20.0)
        XCTAssertEqual(vm.cvkKnobAngle, 20.0)
        XCTAssertEqual(vm.cvkKnobVal, 30.0, accuracy: 0.01)  // 50.0 - (20.0 * 0.5 * 2.0)
    }

    func testRadiusBasedBaseMultipliers() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        vm.currentStep = 3

        let doubleKey = KnobKey(
            bundleID: "com.phantomknob.controlpanel", axRole: "ControlPanel",
            identifier: "DoubleKnob")
        let doubleConfig = KnobCustomizer.shared.knob(for: doubleKey)?.doubleConfig
        let maxInner = doubleConfig?.inner.maxRadius ?? 25.0
        let minR_double = doubleConfig?.inner.minRadius ?? 15.0
        let maxR_double = doubleConfig?.outer.maxRadius ?? 60.0
        let scaleInner = doubleConfig?.inner.unitPerDegree ?? 1.0
        let scaleOuter = doubleConfig?.outer.unitPerDegree ?? 0.1

        // 模拟双环旋钮内圈半径 (例如 20mm)
        let pointsInner = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 140, y: 100),  // 间距 40, 半径 = 20.0
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
            1: CGPoint(x: 260, y: 100),  // 间距 160, 半径 = 80.0
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

        // 模拟无级变速旋钮插值
        let linearKey = KnobKey(
            bundleID: "com.phantomknob.controlpanel", axRole: "ControlPanel",
            identifier: "CVKKnob")
        let cvkConfig = KnobCustomizer.shared.knob(for: linearKey)?.cvkConfig
        let minR = cvkConfig?.minRadius ?? 10.0
        let maxR = cvkConfig?.maxRadius ?? 30.0
        let minScale = cvkConfig?.minScale ?? 0.1
        let maxScale = cvkConfig?.maxScale ?? 5.0

        let pointsMid = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 140, y: 100),  // 间距 40, 半径 = 20.0
        ]
        vm.hoveredKnob = .cvkKnob
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsMid]
        )

        let expectedRatio = (20.0 - minR) / (maxR - minR)
        let expectedMultiplier = maxScale - expectedRatio * (maxScale - minScale)
        let expectedDiameter = OverlayController.calculateDiameter(for: 20.0)

        XCTAssertEqual(vm.cvkKnobBaseMultiplier, expectedMultiplier, accuracy: 0.05)
        XCTAssertEqual(vm.cvkKnobDiameter, expectedDiameter, accuracy: 0.05)

        // Hover out resets diameter to 120
        vm.hoveredKnob = .none
        XCTAssertEqual(vm.doubleKnobDiameter, 120.0)
        XCTAssertEqual(vm.cvkKnobDiameter, 120.0)
    }

    func testUserGuideStep3KnobTooCloseAndDeadzoneBehavior() {
        let vm = UserGuideViewModel(audioService: MockAudioControlService())
        vm.currentStep = 3
        vm.hoveredKnob = .doubleKnob

        XCTAssertFalse(vm.isTooClose)
        XCTAssertFalse(vm.isDeadzone)

        // 1. Simulate two-finger distance very close (< 10mm -> radius < 5.0)
        let pointsTooClose = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 108, y: 100), // distance = 8, radius = 4.0 (< 5.0)
        ]
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsTooClose]
        )

        XCTAssertTrue(vm.isTooClose)

        // 2. Test rotation doesn't change value when isTooClose is true
        let initialVal = vm.doubleKnobVal
        vm.registerRotation(10.0)
        XCTAssertEqual(vm.doubleKnobVal, initialVal)

        // 3. Simulate radius in deadzone (e.g. 7.0, where 7.0 < inner.minRadius = 10.0, but > 5.0 so not isTooClose)
        let pointsDeadzone = [
            0: CGPoint(x: 100, y: 100),
            1: CGPoint(x: 114, y: 100), // distance = 14, radius = 7.0
        ]
        NotificationCenter.default.post(
            name: NSNotification.Name("TouchpadCoordinatesValidated"),
            object: nil,
            userInfo: ["points": pointsDeadzone]
        )

        XCTAssertFalse(vm.isTooClose)
        XCTAssertTrue(vm.isDeadzone)

        // Rotation ignored during deadzone
        vm.registerRotation(10.0)
        XCTAssertEqual(vm.doubleKnobVal, initialVal)

        // 4. Hover out resets isTooClose and isDeadzone
        vm.hoveredKnob = .none
        XCTAssertFalse(vm.isTooClose)
        XCTAssertFalse(vm.isDeadzone)
    }
}

