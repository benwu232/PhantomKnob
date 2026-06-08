import XCTest
@testable import PhantomKnobDetector

final class AppSettingsTests: XCTestCase {
    func testDefaultSettingsIsSingleRadius() {
        let settings = AppSettings()
        XCTAssertEqual(settings.fixed.zones.count, 1)
        XCTAssertEqual(settings.fixed.zones[0].scale, 1.0)
        XCTAssertEqual(settings.fixed.zones[0].minRadius, 5.0)
        XCTAssertEqual(settings.fixed.zones[0].maxRadius, 100.0)
    }
}
