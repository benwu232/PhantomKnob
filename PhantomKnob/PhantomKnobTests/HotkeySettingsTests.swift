import XCTest
@testable import PhantomKnob

final class HotkeySettingsTests: XCTestCase {
    func testDefaultHotkeyValues() {
        // 'O' 键的 keyCode 是 31
        XCTAssertEqual(HotkeySettings.defaultKeyCode, 31)
        XCTAssertEqual(HotkeySettings.defaultModifiers, [.command, .option])
    }
}
