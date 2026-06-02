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
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        let points2: [Int: CGPoint] = [1: CGPoint(x: 10, y: 0), 2: CGPoint(x: 110, y: 0)]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .pan)
    }
    
    func testClassifyKnobGesture() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 10 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50 - 50*cos(radians), y: -50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .knob)
    }
    
    func testAngleThreshold() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 3 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50 - 50*cos(radians), y: -50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        
        XCTAssertEqual(mode, .pan)
    }
    
    func testModeLocksAfterClassification() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 10 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50 - 50*cos(radians), y: -50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50*sin(radians))
        ]
        _ = classifier.processTouchesMoved(points: points2)
        
        let points3: [Int: CGPoint] = [1: CGPoint(x: 0, y: 10), 2: CGPoint(x: 100, y: 10)]
        let mode = classifier.processTouchesMoved(points: points3)
        
        XCTAssertEqual(mode, .knob)
    }
    
    func testResetOnTouchesEnded() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        let radians = 10 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50 - 50*cos(radians), y: -50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50*sin(radians))
        ]
        _ = classifier.processTouchesMoved(points: points2)
        
        classifier.processTouchesEnded()
        
        XCTAssertEqual(classifier.currentMode, .pan)
    }
    
    func testClassifyKnobWithinShortWindow() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟在 0.4 秒时发生旋转，中心点几乎不变
        let radians = 10 * Double.pi / 180
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 50 - 50*cos(radians), y: -50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(mode, .knob, "在 0.8 秒内旋转超过阈值且位移未超标，应当被判定为 knob")
    }
    
    func testTimeoutLocksToPan() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟静止或平移（无旋转）
        let points2: [Int: CGPoint] = [1: CGPoint(x: 10, y: 0), 2: CGPoint(x: 110, y: 0)]
        _ = classifier.processTouchesMoved(points: points2)
        
        // 模拟强行等待 0.9 秒以让 0.8s 的 detectionWindow 超时
        Thread.sleep(forTimeInterval: 0.9)
        
        // 随后发生大角度旋转
        let radians = 15 * Double.pi / 180
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 50 - 50*cos(radians), y: -50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50*sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(mode, .pan, "一旦判定超时，手势应被锁死为 pan，不应再判定为 knob")
    }

    func testCentroidTranslationLocksToPan() {
        let classifier = GestureClassifier()
        
        let points1: [Int: CGPoint] = [1: CGPoint(x: 0, y: 0), 2: CGPoint(x: 100, y: 0)]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟在 0.2 秒时发生大位移（水平拖动 20 个单位，位移 > 15.0 阈值）
        let points2: [Int: CGPoint] = [1: CGPoint(x: 20, y: 0), 2: CGPoint(x: 120, y: 0)]
        let modeMoved = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(modeMoved, .pan, "发生大位移后手势处于 pan 状态")
        
        // 在同一手势期内继续发生大角度旋转
        let radians = 15 * Double.pi / 180
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 70 - 50*cos(radians), y: 0 - 50*sin(radians)),
            2: CGPoint(x: 70 + 50*cos(radians), y: 0 + 50*sin(radians))
        ]
        let modeRotated = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(modeRotated, .pan, "中心平移位移超标后，即使再次旋转也绝不应该触发 knob")
    }
}
