import XCTest
@testable import PhantomKnobDetector

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
        XCTAssertEqual(state.deltaAngle, 1) // clamped to ±1°
    }
    
    func testKnobStateDeltaAngleCalculation() {
        // 正向旋转
        let state1 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 10),
            previous: KnobCore(center: .zero, radius: 10, angle: 5)
        )
        XCTAssertEqual(state1.deltaAngle, 1) // clamped from 5 to 1
        
        // 反向旋转
        let state2 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 5),
            previous: KnobCore(center: .zero, radius: 10, angle: 10)
        )
        XCTAssertEqual(state2.deltaAngle, -1) // clamped from -5 to -1
        
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
        // -170 - 170 = -340, -340 + 360 = 20, clamped to 1
        XCTAssertEqual(state1.deltaAngle, 1)
        
        let state2 = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 170),
            previous: KnobCore(center: .zero, radius: 10, angle: -170)
        )
        // 170 - (-170) = 340, 340 - 360 = -20, clamped to -1
        XCTAssertEqual(state2.deltaAngle, -1)
    }
    
    func testKnobStateRotationDirection() {
        let clockwiseState = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 10),
            previous: KnobCore(center: .zero, radius: 10, angle: 5)
        )
        XCTAssertEqual(clockwiseState.rotationDirection, .clockwise)
        
        let counterClockwiseState = KnobState(
            current: KnobCore(center: .zero, radius: 10, angle: 5),
            previous: KnobCore(center: .zero, radius: 10, angle: 10)
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

final class DetectionResultTests: XCTestCase {
    
    // MARK: - DetectionResult Tests
    
    func testDetectionResultInitialization() {
        let details = DetectionResult.DetectionDetails(
            normalizedPositionAvailable: true,
            sampleCount: 3,
            errorMessage: nil
        )
        let result = DetectionResult(
            isSupported: true,
            timestamp: Date(),
            deviceModel: "MacBookPro18,3",
            macOSVersion: "macOS 14.0",
            details: details
        )
        
        XCTAssertTrue(result.isSupported)
        XCTAssertEqual(result.deviceModel, "MacBookPro18,3")
        XCTAssertEqual(result.macOSVersion, "macOS 14.0")
        XCTAssertTrue(result.details.normalizedPositionAvailable)
        XCTAssertEqual(result.details.sampleCount, 3)
        XCTAssertNil(result.details.errorMessage)
    }
    
    func testDetectionResultUnsupported() {
        let details = DetectionResult.DetectionDetails(
            normalizedPositionAvailable: false,
            sampleCount: 0,
            errorMessage: "无法获取触摸绝对坐标"
        )
        let result = DetectionResult(
            isSupported: false,
            timestamp: Date(),
            deviceModel: "MacBookPro18,3",
            macOSVersion: "macOS 14.0",
            details: details
        )
        
        XCTAssertFalse(result.isSupported)
        XCTAssertFalse(result.details.normalizedPositionAvailable)
        XCTAssertEqual(result.details.errorMessage, "无法获取触摸绝对坐标")
    }
    
    func testDetectionResultCodable() {
        let details = DetectionResult.DetectionDetails(
            normalizedPositionAvailable: true,
            sampleCount: 3,
            errorMessage: nil
        )
        let original = DetectionResult(
            isSupported: true,
            timestamp: Date(),
            deviceModel: "MacBookPro18,3",
            macOSVersion: "macOS 14.0",
            details: details
        )
        
        // 编码
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(original)
        
        // 解码
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode(DetectionResult.self, from: data)
        
        XCTAssertEqual(decoded.isSupported, original.isSupported)
        XCTAssertEqual(decoded.deviceModel, original.deviceModel)
        XCTAssertEqual(decoded.macOSVersion, original.macOSVersion)
        XCTAssertEqual(decoded.details.normalizedPositionAvailable, original.details.normalizedPositionAvailable)
        XCTAssertEqual(decoded.details.sampleCount, original.details.sampleCount)
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
}
