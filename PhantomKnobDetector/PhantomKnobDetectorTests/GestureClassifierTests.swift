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
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        // 平移 0.05 (在 0.08 阈值内，但由于无旋转，应仍为 pan)
        let points2: [Int: CGPoint] = [1: CGPoint(x: 0.35, y: 0.5), 2: CGPoint(x: 0.75, y: 0.5)]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .pan)
    }
    
    func testClassifyKnobGesture() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        // 旋转 12 度，中心点 (0.5, 0.5) 保持不变，半径 0.2
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians), y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians), y: 0.5 + 0.2*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .knob)
    }
    
    func testAngleThreshold() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        // 旋转 5 度 (小于 8.0 度阈值)
        let radians = 5 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians), y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians), y: 0.5 + 0.2*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .pan)
    }
    
    func testModeLocksAfterClassification() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        // 先旋转 12 度激活 knob
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians), y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians), y: 0.5 + 0.2*sin(radians))
        ]
        _ = classifier.processTouchesMoved(points: points2)
        
        // 随后平移 0.2 (即使位移很大，由于已经激活，也应该维持 knob)
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians) + 0.2, y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians) + 0.2, y: 0.5 + 0.2*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points3)
        
        XCTAssertEqual(mode, .knob)
    }
    
    func testResetOnTouchesEnded() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians), y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians), y: 0.5 + 0.2*sin(radians))
        ]
        _ = classifier.processTouchesMoved(points: points2)
        
        classifier.processTouchesEnded()
        
        XCTAssertEqual(classifier.currentMode, .pan)
    }
    
    func testClassifyKnobWithinShortWindow() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 12 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians), y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians), y: 0.5 + 0.2*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(mode, .knob, "在 0.8 秒内旋转超过阈值且位移未超标，应当被判定为 knob")
    }
    
    func testTimeoutLocksToPan() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟微小的平移
        let points2: [Int: CGPoint] = [1: CGPoint(x: 0.32, y: 0.5), 2: CGPoint(x: 0.72, y: 0.5)]
        _ = classifier.processTouchesMoved(points: points2)
        
        // 模拟强行等待 0.9 秒以让 0.8s 的 detectionWindow 超时
        Thread.sleep(forTimeInterval: 0.9)
        
        // 随后发生大角度旋转
        let radians = 15 * Double.pi / 180
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians), y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians), y: 0.5 + 0.2*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(mode, .pan, "一旦判定超时，手势应被锁死为 pan，不应再判定为 knob")
    }

    func testCentroidTranslationLocksToPan() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0.3, y: 0.5), 2: CGPoint(x: 0.7, y: 0.5)]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟在 0.2 秒时发生大位移（向右平移 0.05，位移 0.05 > 0.03 阈值）
        let points2: [Int: CGPoint] = [1: CGPoint(x: 0.35, y: 0.5), 2: CGPoint(x: 0.75, y: 0.5)]
        let modeMoved = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(modeMoved, .pan, "发生大位移后手势处于 pan 状态")
        
        // 在同一手势期内继续发生大角度旋转
        let radians = 15 * Double.pi / 180
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 0.5 - 0.2*cos(radians) + 0.05, y: 0.5 - 0.2*sin(radians)),
            2: CGPoint(x: 0.5 + 0.2*cos(radians) + 0.05, y: 0.5 + 0.2*sin(radians))
        ]
        let modeRotated = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(modeRotated, .pan, "中心平移位移超标后，即使再次旋转也绝不应该触发 knob")
    }
}
