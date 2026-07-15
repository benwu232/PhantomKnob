import XCTest
@testable import PhantomKnob

final class HotkeySettingsTests: XCTestCase {
    func testDefaultHotkeyValues() {
        // 'K' 键的 keyCode 是 40
        XCTAssertEqual(HotkeySettings.defaultKeyCode, 40)
        XCTAssertEqual(HotkeySettings.defaultModifiers, [.command, .option])
    }
}
