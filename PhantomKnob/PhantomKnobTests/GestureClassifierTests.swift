import XCTest
@testable import PhantomKnobDetector
import CoreGraphics

final class GestureClassifierTests: XCTestCase {
    
    func testInitialModeIsPan() {
        let classifier = GestureClassifier()
        XCTAssertEqual(classifier.currentMode, .pan)
    }
    
    func testClassifyPanGesture() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        // 平移 5.0 (超出 3.0 阈值，由于无旋转，应仍为 pan)
        let points2: [Int: CGPoint] = [1: CGPoint(x: 75.0, y: 50.0), 2: CGPoint(x: 35.0, y: 50.0)]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .pan)
    }
    
    func testClassifyKnobGesture() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        // 旋转 12 度，中心点 (50.0, 50.0) 保持不变，半径 20.0
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians), y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians), y: 50.0 - 20.0*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .knob)
    }
    
    func testAngleThreshold() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        // 旋转 5 度 (小于 8.0 度阈值)
        let radians = 5 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians), y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians), y: 50.0 - 20.0*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .pan)
    }
    
    func testModeLocksAfterClassification() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        // 先旋转 12 度激活 knob
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians), y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians), y: 50.0 - 20.0*sin(radians))
        ]
        _ = classifier.processTouchesMoved(points: points2)
        
        // 随后平移 20.0 (即使位移很大，由于已经激活，也应该维持 knob)
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians) + 20.0, y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians) + 20.0, y: 50.0 - 20.0*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points3)
        
        XCTAssertEqual(mode, .knob)
    }
    
    func testResetOnTouchesEnded() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians), y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians), y: 50.0 - 20.0*sin(radians))
        ]
        _ = classifier.processTouchesMoved(points: points2)
        
        classifier.processTouchesEnded()
        
        XCTAssertEqual(classifier.currentMode, .pan)
    }
    
    func testClassifyKnobWithinShortWindow() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians), y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians), y: 50.0 - 20.0*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(mode, .knob, "在 0.8 秒内旋转超过阈值且位移未超标，应当被判定为 knob")
    }
    
    func testTimeoutLocksToPan() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟微小的平移 2.0 (在 3.0 阈值内)
        let points2: [Int: CGPoint] = [1: CGPoint(x: 72.0, y: 50.0), 2: CGPoint(x: 32.0, y: 50.0)]
        _ = classifier.processTouchesMoved(points: points2)
        
        // 模拟强行等待 0.9 秒以让 0.8s 的 detectionWindow 超时
        Thread.sleep(forTimeInterval: 0.9)
        
        // 随后发生大角度旋转
        let radians = 15 * Double.pi / 180
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians), y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians), y: 50.0 - 20.0*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(mode, .pan, "一旦判定超时，手势应被锁死为 pan，不应再判定为 knob")
    }

    func testCentroidTranslationLocksToPan() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 70.0, y: 50.0), 2: CGPoint(x: 30.0, y: 50.0)]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟在 0.2 秒时发生大位移（向右平移 5.0，位移 5.0 > 3.0 阈值）
        let points2: [Int: CGPoint] = [1: CGPoint(x: 75.0, y: 50.0), 2: CGPoint(x: 35.0, y: 50.0)]
        let modeMoved = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(modeMoved, .pan, "发生大位移后手势处于 pan 状态")
        
        // 在同一手势期内继续发生大角度旋转
        let radians = 15 * Double.pi / 180
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 50.0 + 20.0*cos(radians) + 5.0, y: 50.0 + 20.0*sin(radians)),
            2: CGPoint(x: 50.0 - 20.0*cos(radians) + 5.0, y: 50.0 - 20.0*sin(radians))
        ]
        let modeRotated = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(modeRotated, .pan, "中心平移位移超标后，即使再次旋转也绝不应该触发 knob")
    }
}
