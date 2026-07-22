import XCTest
@testable import PhantomKnob

final class ReleaseNotesTests: XCTestCase {
    
    func testReleaseNotesLoadingAndParsing() {
        let controller = ReleaseNotesController.shared
        
        // Test loading version 1.0 which we defined in release-notes.json
        let notes = controller.loadReleaseNotes(for: "1.0")
        
        XCTAssertNotNil(notes, "Failed to load release notes for version 1.0")
        XCTAssertEqual(notes?.title, "Welcome to PhantomKnob!")
        XCTAssertEqual(notes?.items.count, 4)
        
        XCTAssertEqual(notes?.items[0], "🎛️ Global knob control with two-finger rotation gesture")
        XCTAssertEqual(notes?.items[1], "🎬 Pro knob packs for DaVinci Resolve, Final Cut Pro, and Logic Pro")
        XCTAssertEqual(notes?.items[2], "⚡ Three knob modes: Fixed, Double-Ring, and Variable Speed")
        XCTAssertEqual(notes?.items[3], "🔧 Full customization with Customizer HUD")
    }
    
    func testReleaseNotesFirstLaunchAndUpgrade() {
        let suiteName = "ReleaseNotesTestsSuite"
        UserDefaults.app = UserDefaults(suiteName: suiteName) ?? .standard
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        
        let controller = ReleaseNotesController.shared
        controller.currentVersionOverride = "1.0"
        
        defer {
            controller.currentVersionOverride = nil
            UserDefaults.app.removePersistentDomain(forName: suiteName)
            UserDefaults.app = .standard
        }
        
        // 1. Initially lastSeenReleaseNotesVersion is nil
        XCTAssertNil(UserDefaults.app.string(forKey: "lastSeenReleaseNotesVersion"))
        
        // Guide completed must be true for ReleaseNotes to be evaluated
        UserDefaults.app.set(true, forKey: "firstRunUserGuideCompleted")
        
        // Call showIfNeeded
        controller.showIfNeeded()
        
        // Verify it did not show and directly marked current version as seen
        XCTAssertFalse(controller.isVisible)
        let currentVersion = controller.currentVersion
        XCTAssertEqual(UserDefaults.app.string(forKey: "lastSeenReleaseNotesVersion"), currentVersion)
        
        // 2. Upgrade Scenario: set lastSeen to older version
        UserDefaults.app.set("0.9", forKey: "lastSeenReleaseNotesVersion")
        
        // Call showIfNeeded
        controller.showIfNeeded()
        
        // Verify it displays the release notes window now
        XCTAssertTrue(controller.isVisible)
        
        // Dismiss the release notes
        controller.hide()
        
        // Verify it is closed
        XCTAssertFalse(controller.isVisible)
    }
}
