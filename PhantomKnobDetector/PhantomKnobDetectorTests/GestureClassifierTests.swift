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
            1: CGPoint(x: 50 - 50*cos(radians), y: 50 - 50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50 + 50*sin(radians))
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
            1: CGPoint(x: 50 - 50*cos(radians), y: 50 - 50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50 + 50*sin(radians))
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
            1: CGPoint(x: 50 - 50*cos(radians), y: 50 - 50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50 + 50*sin(radians))
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
            1: CGPoint(x: 50 - 50*cos(radians), y: 50 - 50*sin(radians)),
            2: CGPoint(x: 50 + 50*cos(radians), y: 50 + 50*sin(radians))
        ]
        _ = classifier.processTouchesMoved(points: points2)
        
        classifier.processTouchesEnded()
        
        XCTAssertEqual(classifier.currentMode, .pan)
    }
}
