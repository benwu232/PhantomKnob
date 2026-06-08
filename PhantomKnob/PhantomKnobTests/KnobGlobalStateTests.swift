// PhantomKnobDetector/PhantomKnobDetectorTests/KnobGlobalStateTests.swift
import XCTest
@testable import PhantomKnobDetector

final class KnobGlobalStateTests: XCTestCase {

    // 辅助函数
    private func mockTarget(identifier: String? = "mock") -> DetectedTarget {
        DetectedTarget(bundleID: "com.test.app", axRole: "AXSlider",
                       identifier: identifier, displayName: "Test", element: nil)
    }

    func testInitialStateIsInactive() {
        XCTAssertEqual(KnobGlobalState.inactive, .inactive)
    }

    func testStateHasIconColor() {
        XCTAssertEqual(KnobGlobalState.inactive.iconColor, .gray)
        XCTAssertEqual(KnobGlobalState.activated.iconColor, .systemBlue)
        XCTAssertEqual(KnobGlobalState.knobing(target: mockTarget()).iconColor, .systemOrange)
        XCTAssertEqual(KnobGlobalState.cooling(target: mockTarget()).iconColor, .systemOrange)
    }

    func testStateHasTarget() {
        XCTAssertNil(KnobGlobalState.inactive.currentTarget)
        XCTAssertNil(KnobGlobalState.activated.currentTarget)
        XCTAssertNotNil(KnobGlobalState.knobing(target: mockTarget()).currentTarget)
        XCTAssertNotNil(KnobGlobalState.cooling(target: mockTarget()).currentTarget)
    }

    func testHotkeyTransitions() {
        XCTAssertEqual(KnobGlobalState.inactive.transition(event: .hotkeyToggle), .activated)
        XCTAssertEqual(KnobGlobalState.activated.transition(event: .hotkeyToggle), .inactive)
    }

    func testGestureStartedWithTargetEntersKnobing() {
        let result = KnobGlobalState.activated.transitionWithResult(
            event: .gestureStartedWithTarget(mockTarget()))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.state.isKnobing)
    }

    func testGestureEndedEntersCooling() {
        let result = KnobGlobalState.knobing(target: mockTarget()).transitionWithResult(event: .gestureEnded)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.state.isCooling)
    }

    func testCoolingTimeoutReturnsToActivated() {
        let next = KnobGlobalState.cooling(target: mockTarget()).transition(event: .coolingTimeout)
        XCTAssertEqual(next, .activated)
    }

    func testAppSwitchedReturnsToActivated() {
        XCTAssertEqual(KnobGlobalState.knobing(target: mockTarget()).transition(event: .appSwitched), .activated)
        XCTAssertEqual(KnobGlobalState.cooling(target: mockTarget()).transition(event: .appSwitched), .activated)
    }

    func testCoolingResumesKnobingOnSameTarget() {
        let target = mockTarget(identifier: "slider-1")
        let result = KnobGlobalState.cooling(target: target).transitionWithResult(
            event: .gestureStartedWithTarget(mockTarget(identifier: "slider-1")))
        XCTAssertTrue(result?.state.isKnobing == true)
    }

    func testCoolingReturnsToActivatedOnDifferentTarget() {
        let result = KnobGlobalState.cooling(target: mockTarget(identifier: "a")).transitionWithResult(
            event: .gestureStartedWithTarget(mockTarget(identifier: "b")))
        XCTAssertEqual(result?.state, .activated)
    }
}
