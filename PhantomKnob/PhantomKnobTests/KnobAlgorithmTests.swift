import XCTest
@testable import PhantomKnobDetector

final class KnobAlgorithmTests: XCTestCase {
    
    var algorithm: KnobAlgorithm!
    
    override func setUp() {
        algorithm = KnobAlgorithm()
    }
    
    func testSinglePoint() {
        let points: [Int: CGPoint] = [1: CGPoint(x: 0.5, y: 0.5)]
        let (knob, _, _) = algorithm.calKnob(points)
        XCTAssertFalse(knob.isValid)
    }
    
    func testTwoPointsHorizontal() {
        let points: [Int: CGPoint] = [
            1: CGPoint(x: 0.3, y: 0.5),
            2: CGPoint(x: 0.7, y: 0.5)
        ]
        let (knob, id1, id2) = algorithm.calKnob(points)
        
        XCTAssertTrue(knob.isValid)
        XCTAssertEqual(knob.center.x, 0.5)
        XCTAssertEqual(knob.center.y, 0.5)
        XCTAssertTrue(id1 < id2)
    }
    
    func testTwoPointsVertical() {
        let points: [Int: CGPoint] = [
            1: CGPoint(x: 0.5, y: 0.3),
            2: CGPoint(x: 0.5, y: 0.7)
        ]
        let (knob, _, _) = algorithm.calKnob(points)
        
        XCTAssertTrue(knob.isValid)
        XCTAssertEqual(knob.center.x, 0.5)
        XCTAssertEqual(knob.center.y, 0.5)
    }
    
    func testThreePoints() {
        let points: [Int: CGPoint] = [
            1: CGPoint(x: 0.1, y: 0.1),
            2: CGPoint(x: 0.5, y: 0.5),
            3: CGPoint(x: 0.9, y: 0.9)
        ]
        let (knob, id1, id2) = algorithm.calKnob(points)
        
        XCTAssertTrue(knob.isValid)
        let minId = min(id1, id2)
        let maxId = max(id1, id2)
        XCTAssertTrue((minId == 1 && maxId == 3) || (minId == 3 && maxId == 1))
    }
    
    func testCenterCalculation() {
        let points: [Int: CGPoint] = [
            1: CGPoint(x: 0.0, y: 0.0),
            2: CGPoint(x: 1.0, y: 1.0)
        ]
        let (knob, _, _) = algorithm.calKnob(points)
        
        XCTAssertEqual(knob.center.x, 0.5)
        XCTAssertEqual(knob.center.y, 0.5)
    }
    
    func testTwoPointsYOrder() {
        let points: [Int: CGPoint] = [
            1: CGPoint(x: 0.5, y: 0.2),
            2: CGPoint(x: 0.5, y: 0.8)
        ]
        let (_, id1, id2) = algorithm.calKnob(points)
        XCTAssertEqual(id1, 2)
        XCTAssertEqual(id2, 1)
    }
    
    func testEmptyPoints() {
        let points: [Int: CGPoint] = [:]
        let (knob, _, _) = algorithm.calKnob(points)
        XCTAssertFalse(knob.isValid)
    }
}
