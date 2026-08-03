import XCTest
@testable import PhantomKnob

final class KnobLiftoffFilterTests: XCTestCase {
    
    func testAngleHistoryBufferTailFreezing() {
        // 验证给定一串包含离板微跳跃的角度历史输入（如 [0, 10, 20, 18]），
        // 当调用 resolvedLiftoffAngle() 时，能够正确丢弃尾部 18° 并锁定在稳定帧 20°
        var buffer = KnobAngleBuffer(capacity: 3, timeWindowSec: 0.03)
        let now = Date()
        buffer.append(angle: 0, timestamp: now.addingTimeInterval(-0.03))
        buffer.append(angle: 10, timestamp: now.addingTimeInterval(-0.02))
        buffer.append(angle: 20, timestamp: now.addingTimeInterval(-0.01))
        buffer.append(angle: 18, timestamp: now) // 尾部跳跃帧
        
        let resolvedAngle = buffer.resolvedLiftoffAngle()
        XCTAssertEqual(resolvedAngle ?? 0, 20.0, accuracy: 0.001, "应该丢弃尾部反弹帧 18° 并锁定在倒数稳定帧 20°")
    }
    
    func testKnobAngleBufferClearAndOverflow() {
        var buffer = KnobAngleBuffer(capacity: 3, timeWindowSec: 0.03)
        buffer.append(angle: 10)
        buffer.append(angle: 20)
        buffer.append(angle: 30)
        buffer.append(angle: 40) // 容量为 3，应该丢弃最早的 10，剩 [20, 30, 40]
        
        XCTAssertEqual(buffer.resolvedLiftoffAngle() ?? 0, 30.0, accuracy: 0.001, "应该倒数第二帧 30°")
        
        buffer.clear()
        XCTAssertNil(buffer.resolvedLiftoffAngle(), "清空后 resolvedLiftoffAngle 应该为 nil")
    }
    
    func testInstantMovedProcessingNoLock() {
        // 验证在移除了 100ms 保护锁后，所有的 Angle 更新与 Buffer 追加是即时且连续的
        var buffer = KnobAngleBuffer(capacity: 3)
        buffer.append(angle: 45.0)
        buffer.append(angle: 90.0)
        
        XCTAssertEqual(buffer.frames.count, 2)
        XCTAssertEqual(buffer.resolvedLiftoffAngle() ?? 0, 45.0, accuracy: 0.001)
    }
}


