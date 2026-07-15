import XCTest
@testable import PhantomKnob

final class HotkeySettingsTests: XCTestCase {
    func testDefaultHotkeyValues() {
        // 'Q' 键的 keyCode 是 12
        XCTAssertEqual(HotkeySettings.defaultKeyCode, 12)
        XCTAssertEqual(HotkeySettings.defaultModifiers, [.command, .option])
    }
}
