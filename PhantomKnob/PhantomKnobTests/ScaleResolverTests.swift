// PhantomKnobTests/ScaleResolverTests.swift
import XCTest
@testable import PhantomKnob

final class ScaleResolverTests: XCTestCase {
    func testHysteresisZonesAndDeadzone() {
        let zones = [
            RadiusZone(minRadius: 5.0, maxRadius: 12.0, margin: 2.0, scale: 1.0),
            RadiusZone(minRadius: 12.0, maxRadius: 100.0, margin: 2.0, scale: 0.2)
        ]
        
        var zoneIndex = 0
        
        // 低于 5.0 触发死区返回 nil
        XCTAssertNil(ScaleResolver.resolveHysteresis(radius: 4.5, zones: zones, currentZoneIndex: &zoneIndex))
        
        // 初始留在 Zone 0
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 6.0, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(zoneIndex, 0)
        
        // 大于 max + margin (12 + 2 = 14) 才进入 Zone 1
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 13.0, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 14.5, zones: zones, currentZoneIndex: &zoneIndex), 0.2)
        XCTAssertEqual(zoneIndex, 1)
        
        // 小于 min - margin (12 - 2 = 10) 才返回 Zone 0
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 11.0, zones: zones, currentZoneIndex: &zoneIndex), 0.2)
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 9.5, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(zoneIndex, 0)
    }

    func testLinearInterpolationAndDeadzone() {
        let config = ScaleConfigLinear(minRadius: 5.0, maxRadius: 20.0, minScale: 1.0, maxScale: 0.2)
        
        XCTAssertNil(ScaleResolver.resolveLinear(radius: 4.5, config: config))
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 5.0, config: config), 1.0)
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 25.0, config: config), 0.2)
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 12.5, config: config), 0.6)
    }
}
