import XCTest
@testable import PhantomKnob

class KnobActiveStatePersistenceTests: XCTestCase {
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "KnobActiveStatePersistenceTests_\(UUID().uuidString)")!
        UserDefaults.app = testDefaults
    }

    override func tearDown() {
        if let defaults = testDefaults {
            defaults.removePersistentDomain(forName: defaults.description)
        }
        testDefaults = nil
        UserDefaults.app = .standard
        super.tearDown()
    }

    func testUserDefaultsDefaultValues() {
        XCTAssertTrue(UserDefaults.app.restoreActiveStateOnStartup)
        XCTAssertFalse(UserDefaults.app.lastKnobActiveState)
    }

    func testUserDefaultsPropertyMutations() {
        UserDefaults.app.restoreActiveStateOnStartup = false
        XCTAssertFalse(UserDefaults.app.restoreActiveStateOnStartup)

        UserDefaults.app.lastKnobActiveState = true
        XCTAssertTrue(UserDefaults.app.lastKnobActiveState)
    }
}
