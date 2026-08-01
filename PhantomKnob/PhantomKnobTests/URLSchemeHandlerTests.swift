import XCTest
@testable import PhantomKnob

final class URLSchemeHandlerTests: XCTestCase {
    func testURLSchemeParsing() {
        let testURL = URL(string: "phantomknob://activate?key=ABCD-1234&email=tester@example.com")!
        
        let expectation = self.expectation(description: "Notification received")
        var receivedKey: String?
        var receivedEmail: String?
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TriggerLicenseActivationFromURL"),
            object: nil,
            queue: .main
        ) { notification in
            receivedKey = notification.userInfo?["key"] as? String
            receivedEmail = notification.userInfo?["email"] as? String
            expectation.fulfill()
        }
        
        URLSchemeHandler.shared.parseAndTriggerActivation(url: testURL)
        
        waitForExpectations(timeout: 2.0) { _ in
            NotificationCenter.default.removeObserver(observer)
            XCTAssertEqual(receivedKey, "ABCD-1234")
            XCTAssertEqual(receivedEmail, "tester@example.com")
        }
    }
}
