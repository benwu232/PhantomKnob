import XCTest
@testable import PhantomKnobDetector

class OverlayControllerTests: XCTestCase {
    
    // 测试半径公式换算及 Clamping [40, 300]
    func testDiameterCalculation() {
        let testCases: [(radius: Double, expectedDiameter: CGFloat)] = [
            (2.0, 40.0),   // 2mm * 2 * 5 = 20, clamped to 40
            (5.0, 50.0),   // 5mm * 2 * 5 = 50
            (15.0, 150.0), // 15mm * 2 * 5 = 150
            (30.0, 300.0), // 30mm * 2 * 5 = 300
            (45.0, 300.0)  // 45mm * 2 * 5 = 450, clamped to 300
        ]
        
        for tc in testCases {
            let calculated = OverlayController.calculateDiameter(for: tc.radius)
            XCTAssertEqual(calculated, tc.expectedDiameter, accuracy: 0.001)
        }
    }
    
    // 测试碰撞逃逸位置选择
    func testQuadrantCollisionAvoidance() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1000, height: 1000)
        let diameter: CGFloat = 100
        
        // Case 1: 鼠标在中间 (500, 500)，右下可以放下
        let posCenter = CGPoint(x: 500, y: 500)
        let frame1 = OverlayController.calculateBestFrame(
            cursor: posCenter,
            diameter: diameter,
            visibleFrame: visibleFrame
        )
        // 预期右下圆心：x = 500 + 105 = 605, y = 500 - 105 = 395
        // 对应直径 100 的窗口 origin 应该是：
        // x = 605 - 50 = 555
        // y = 395 - 50 = 345
        XCTAssertEqual(frame1.origin.x, 555)
        XCTAssertEqual(frame1.origin.y, 345)
        
        // Case 2: 鼠标在右下角 (950, 50)，右下、右上、左下均越界，应该使用左上
        let posBottomRight = CGPoint(x: 950, y: 50)
        let frame2 = OverlayController.calculateBestFrame(
            cursor: posBottomRight,
            diameter: diameter,
            visibleFrame: visibleFrame
        )
        // 左上圆心 x = 950 - 105 = 845, y = 50 + 105 = 155
        // 对应直径 100 的窗口 origin 应该是：
        // x = 845 - 50 = 795
        // y = 155 - 50 = 105
        XCTAssertEqual(frame2.origin.x, 795)
        XCTAssertEqual(frame2.origin.y, 105)
        
        // Case 3: 鼠标在左下角 (10, 10)，越界，夹紧在屏幕边界
        let posCorner = CGPoint(x: 10, y: 10)
        let frame3 = OverlayController.calculateBestFrame(
            cursor: posCorner,
            diameter: diameter,
            visibleFrame: visibleFrame
        )
        // 保证 x >= 0, y >= 0
        XCTAssertGreaterThanOrEqual(frame3.origin.x, 0)
        XCTAssertGreaterThanOrEqual(frame3.origin.y, 0)
    }
}
