// PhantomKnobDetectorTests/ScaleConfigCompatibilityTests.swift
import XCTest
@testable import PhantomKnobDetector

final class ScaleConfigCompatibilityTests: XCTestCase {
    func testDecodeLegacyFixedScale() throws {
        let json = "{\"fixed\": 2.5}"
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ScaleConfig.self, from: data)
        if case .fixed(let val) = config {
            XCTAssertEqual(val, 2.5)
        } else {
            XCTFail("Expected .fixed")
        }
    }

    func testDecodeZonesScale() throws {
        let json = """
        {
            "zones": [
                {"minRadius": 0.0, "maxRadius": 10.0, "margin": 1.5, "scale": 1.5},
                {"minRadius": 10.0, "maxRadius": 100.0, "margin": 1.5, "scale": 0.3}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ScaleConfig.self, from: data)
        if case .zones(let zones) = config {
            XCTAssertEqual(zones.count, 2)
            XCTAssertEqual(zones[0].scale, 1.5)
            XCTAssertEqual(zones[1].margin, 1.5)
        } else {
            XCTFail("Expected .zones")
        }
    }
}
