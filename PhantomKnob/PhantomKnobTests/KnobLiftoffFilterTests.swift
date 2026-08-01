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
    
    func testMultitouchManagerFilterBreakingContacts() {
        // 验证接触状态包含 state=5 (breaking) 或 6 (lingering) 时，被正确判断为离板阶段
        let statesTouching: [Int32] = [4, 4]
        let statesBreaking: [Int32] = [4, 5]
        let statesLingering: [Int32] = [6, 4]
        
        XCTAssertFalse(MultitouchManager.isAnyContactReleasing(states: statesTouching), "全状态为 4 时不应判定为离板")
        XCTAssertTrue(MultitouchManager.isAnyContactReleasing(states: statesBreaking), "包含 state=5 (breaking) 时应该判定为 isReleasing == true")
        XCTAssertTrue(MultitouchManager.isAnyContactReleasing(states: statesLingering), "包含 state=6 (lingering) 时应该判定为 isReleasing == true")
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
    
    func testTwoToOneTransitionLockWindow() {
        let now = Date()
        let lockTime = now
        
        let timeInWindow = now.addingTimeInterval(0.05)
        let isLockedInWindow = timeInWindow.timeIntervalSince(lockTime) < 0.100
        XCTAssertTrue(isLockedInWindow, "50ms 时应处于 100ms 锁定保护期")
        
        let timeAfterWindow = now.addingTimeInterval(0.12)
        let isLockedAfterWindow = timeAfterWindow.timeIntervalSince(lockTime) < 0.100
        XCTAssertFalse(isLockedAfterWindow, "120ms 时应解除 100ms 锁定保护")
    }
}
