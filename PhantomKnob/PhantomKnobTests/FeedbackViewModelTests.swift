import XCTest
@testable import PhantomKnob

final class FeedbackViewModelTests: XCTestCase {
    func testGenerateDiagnosticInfoContainsRequiredFields() {
        let viewModel = FeedbackViewModel()
        let diagnostics = viewModel.generateDiagnosticInfo()
        
        XCTAssertTrue(diagnostics.contains("App: PhantomKnob"))
        XCTAssertTrue(diagnostics.contains("macOS:"))
        XCTAssertTrue(diagnostics.contains("Device:"))
        XCTAssertTrue(diagnostics.contains("License:"))
    }
    
    func testMailtoURLConstruction() {
        let viewModel = FeedbackViewModel()
        let url = viewModel.buildMailtoURL()
        
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.starts(with: "mailto:phantomknob232@gmail.com") ?? false)
        XCTAssertTrue(url?.absoluteString.contains("subject=") ?? false)
    }
    
    func testGitHubURLConstruction() {
        let viewModel = FeedbackViewModel()
        let url = viewModel.gitHubIssuesURL
        
        XCTAssertEqual(url.absoluteString, "https://github.com/benwu232/PhantomKnob/issues/new")
    }
}
