import XCTest
@testable import PhantomKnobDetector

final class KnobGlobalStateTests: XCTestCase {
    
    func testInitialStateIsInactive() {
        let state = KnobGlobalState.inactive
        XCTAssertEqual(state, .inactive)
    }
    
    func testStateHasIconColor() {
        XCTAssertEqual(KnobGlobalState.inactive.iconColor, .gray)
        XCTAssertEqual(KnobGlobalState.activated.iconColor, .systemBlue)
        
        // 带关联值的 case 需要提供目标
        let target = MockControlTarget()
        XCTAssertEqual(KnobGlobalState.knobing(target: target).iconColor, .systemOrange)
        XCTAssertEqual(KnobGlobalState.cooling(target: target).iconColor, .systemOrange)
    }
    
    func testStateHasTarget() {
        XCTAssertNil(KnobGlobalState.inactive.currentTarget)
        XCTAssertNil(KnobGlobalState.activated.currentTarget)
        
        let target = MockControlTarget()
        XCTAssertNotNil(KnobGlobalState.knobing(target: target).currentTarget)
        XCTAssertNotNil(KnobGlobalState.cooling(target: target).currentTarget)
    }
    
    func testStateTransitionByHotkey() {
        let transition = KnobGlobalState.inactive.transition(event: .hotkeyToggle)
        XCTAssertEqual(transition, .activated)
        
        let backTransition = KnobGlobalState.activated.transition(event: .hotkeyToggle)
        XCTAssertEqual(backTransition, .inactive)
    }
    
    func testStateTransitionByGestureStart() {
        let transition = KnobGlobalState.activated.transition(event: .gestureStarted)
        XCTAssertEqual(transition, .activated)
    }
    
    func testStateTransitionByGestureWithTarget() {
        let target = MockControlTarget()
        let result = KnobGlobalState.activated.transitionWithResult(
            event: .gestureStartedWithTarget(target, angleDelta: 6.0)
        )
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.state.isKnobing)
        XCTAssertNotNil(result!.target)
    }
    
    func testStateTransitionByGestureWithBelowThreshold() {
        let target = MockControlTarget()
        let result = KnobGlobalState.activated.transitionWithResult(
            event: .gestureStartedWithTarget(target, angleDelta: 3.0)
        )
        XCTAssertNil(result)
    }
    
    func testStateTransitionByGestureEnd() {
        let target = MockControlTarget()
        let result = KnobGlobalState.knobing(target: target).transitionWithResult(event: .gestureEnded)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.state.isCooling)
    }
    
    func testStateTransitionByCoolingTimeout() {
        let target = MockControlTarget()
        let transition = KnobGlobalState.cooling(target: target).transition(event: .coolingTimeout)
        XCTAssertEqual(transition, .activated)
    }
    
    func testStateTransitionByAppSwitch() {
        let target = MockControlTarget()
        let transition = KnobGlobalState.knobing(target: target).transition(event: .appSwitched)
        XCTAssertEqual(transition, .activated)
    }
}

class MockControlTarget: ControlTarget {
    var value: Double = 50.0
    let minValue: Double = 0
    let maxValue: Double = 100
    let displayName: String = "Mock Target"
    
    func applyDelta(_ deltaAngle: Double) -> Double {
        value = (value + deltaAngle * 0.5).clamped(to: minValue...maxValue)
        return value
    }
}
