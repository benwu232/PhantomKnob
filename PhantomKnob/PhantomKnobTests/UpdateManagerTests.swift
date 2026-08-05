import XCTest
@testable import PhantomKnob

final class UpdateManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "SUEnableAutomaticChecks")
        UserDefaults.standard.removeObject(forKey: "SUAutomaticallyUpdate")
    }
    
    func testUpdateManagerProperties() {
        let manager = UpdateManager.shared
        XCTAssertNotNil(manager)
        // Verify canCheckForUpdates property evaluates without crash
        _ = manager.canCheckForUpdates
    }
    
    func testAutomaticCheckSettingsBinding() {
        let manager = UpdateManager.shared
        manager.automaticallyChecksForUpdates = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks"))
        
        manager.automaticallyChecksForUpdates = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks"))
    }
    
    func testAutomaticDownloadSettingsBinding() {
        let manager = UpdateManager.shared
        manager.automaticallyDownloadsUpdates = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate"))
        
        manager.automaticallyDownloadsUpdates = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate"))
    }
    
    func testSUFeedURLConfigurationValid() {
        let feedURLString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        XCTAssertNotNil(feedURLString, "SUFeedURL should be configured in Info.plist")
        XCTAssertTrue(feedURLString?.hasPrefix("https://") == true, "SUFeedURL must use HTTPS scheme")
    }
}

