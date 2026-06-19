import XCTest
@testable import PhantomKnob

final class RotationDirectionTests: XCTestCase {
    
    // MARK: - RotationDirection Tests
    
    func testRotationDirectionCases() {
        // 验证所有枚举值存在
        let clockwise = RotationDirection.clockwise
        let counterClockwise = RotationDirection.counterClockwise
        let none = RotationDirection.none
        
        // 验证枚举值不相等
        XCTAssertNotEqual(clockwise, counterClockwise)
        XCTAssertNotEqual(clockwise, none)
        XCTAssertNotEqual(counterClockwise, none)
    }
}

final class KnobCoreTests: XCTestCase {
    
    // MARK: - KnobCore Tests
    
    func testKnobCoreInitialization() {
        let center = CGPoint(x: 0.5, y: 0.5)
        let knob = KnobCore(center: center, radius: 10, angle: 45)
        
        XCTAssertEqual(knob.center.x, 0.5)
        XCTAssertEqual(knob.center.y, 0.5)
        XCTAssertEqual(knob.radius, 10)
        XCTAssertEqual(knob.angle, 45)
    }
    
    func testKnobCoreDefaultInitialization() {
        let knob = KnobCore()
        
        XCTAssertEqual(knob.center.x, 0)
        XCTAssertEqual(knob.center.y, 0)
        XCTAssertEqual(knob.radius, 0)
        XCTAssertEqual(knob.angle, 0)
    }
    
    func testKnobCoreIsValid() {
        let validKnob = KnobCore(center: .zero, radius: 10, angle: 0)
        let invalidKnob = KnobCore(center: .zero, radius: 0, angle: 0)
        let negativeRadiusKnob = KnobCore(center: .zero, radius: -5, angle: 0)
        
        XCTAssertTrue(validKnob.isValid)
        XCTAssertFalse(invalidKnob.isValid)
        XCTAssertFalse(negativeRadiusKnob.isValid)
    }
    
    func testKnobCoreInvalidStatic() {
        let invalid = KnobCore.invalid
        
        XCTAssertEqual(invalid.center.x, 0)
        XCTAssertEqual(invalid.center.y, 0)
        XCTAssertEqual(invalid.radius, 0)
        XCTAssertEqual(invalid.angle, 0)
        XCTAssertFalse(invalid.isValid)
    }
}

final class KnobStateTests: XCTestCase {
    
    // MARK: - KnobState Tests
    
    func testKnobStateInitialization() {
        let current = KnobCore(center: .zero, radius: 10, angle: 45)
        let previous = KnobCore(center: .zero, radius: 10, angle: 30)
        let state = KnobState(current: current, previous: previous)
        
        XCTAssertEqual(state.current.angle, 45)
        XCTAssertEqual(state.previous.angle, 30)
        XCTAssertEqual(state.deltaAngle, -1.0, accuracy: 0.01) // clamped to ±1° (counter-clockwise -> negative delta)
    }
    
    func testKnobStateDeltaAngleCalculation() {
        // 逆时针旋转
        let state1 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 10),
            previous: KnobCore(center: .zero, radius: 10, angle: 5)
        )
        XCTAssertEqual(state1.deltaAngle, -1.0, accuracy: 0.01) // clamped from -5 to -1
        
        // 顺时针旋转
        let state2 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 5),
            previous: KnobCore(center: .zero, radius: 10, angle: 10)
        )
        XCTAssertEqual(state2.deltaAngle, 1.0, accuracy: 0.01) // clamped from 5 to 1
        
        // 无变化
        let state3 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 45),
            previous: KnobCore(center: .zero, radius: 10, angle: 45)
        )
        XCTAssertEqual(state3.deltaAngle, 0)
    }
    
    func testKnobStateAngleWrapping() {
        // 跨越 ±180° 的情況
        let state1 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: -170),
            previous: KnobCore(center: .zero, radius: 10, angle: 170)
        )
        // -170 - 170 = -340, -340 + 360 = 20, clamped to -1 (counter-clockwise)
        XCTAssertEqual(state1.deltaAngle, -1.0, accuracy: 0.01)
        
        let state2 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 170),
            previous: KnobCore(center: .zero, radius: 10, angle: -170)
        )
        // 170 - (-170) = 340, 340 - 360 = -20, clamped to 1 (clockwise)
        XCTAssertEqual(state2.deltaAngle, 1.0, accuracy: 0.01)
    }
    
    func testKnobStateRotationDirection() {
        let clockwiseState = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 5),
            previous: KnobCore(center: .zero, radius: 10, angle: 10)
        )
        XCTAssertEqual(clockwiseState.rotationDirection, .clockwise)
        
        let counterClockwiseState = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 10),
            previous: KnobCore(center: .zero, radius: 10, angle: 5)
        )
        XCTAssertEqual(counterClockwiseState.rotationDirection, .counterClockwise)
        
        let noRotationState = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 45),
            previous: KnobCore(center: .zero, radius: 10, angle: 45)
        )
        XCTAssertEqual(noRotationState.rotationDirection, .none)
    }
    
    func testKnobStateDefaultInitialization() {
        let state = KnobState()
        
        XCTAssertFalse(state.current.isValid)
        XCTAssertFalse(state.previous.isValid)
        XCTAssertEqual(state.deltaAngle, 0)
        XCTAssertEqual(state.rotationDirection, .none)
    }
}

final class ComparableExtensionTests: XCTestCase {
    
    // MARK: - Comparable Extension Tests
    
    func testClampedWithinRange() {
        XCTAssertEqual(5.clamped(to: 0...10), 5)
        XCTAssertEqual(0.5.clamped(to: 0.0...1.0), 0.5)
    }
    
    func testClampedBelowRange() {
        XCTAssertEqual((-5).clamped(to: 0...10), 0)
        XCTAssertEqual((-0.5).clamped(to: 0.0...1.0), 0.0)
    }
    
    func testClampedAboveRange() {
        XCTAssertEqual(15.clamped(to: 0...10), 10)
        XCTAssertEqual(1.5.clamped(to: 0.0...1.0), 1.0)
    }

    func testControlRuleCustomStyleDecoding() throws {
        let json = """
        {
            "key": {
                "bundleID": "com.apple.FinalCut",
                "axRole": "AXSlider"
            },
            "translation": "axWrite",
            "scaleConfig": {
                "fixed": 1.5
            },
            "themeColor": "#0A84FF",
            "overlayStyle": "minimal",
            "rotationStyle": "cleanArc"
        }
        """.data(using: .utf8)!
        
        let rule = try JSONDecoder().decode(ControlRule.self, from: json)
        XCTAssertEqual(rule.themeColor, "#0A84FF")
        XCTAssertEqual(rule.overlayStyle, "minimal")
        XCTAssertEqual(rule.rotationStyle, "cleanArc")
    }
}
