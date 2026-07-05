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
}
