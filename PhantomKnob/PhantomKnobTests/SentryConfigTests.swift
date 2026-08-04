import XCTest
#if canImport(Sentry)
import Sentry
#endif
@testable import PhantomKnob

final class SentryConfigTests: XCTestCase {
    func testSentryOptionsConfiguration() {
        #if canImport(Sentry)
        let options = Options()
        SentryManager.configureOptions(options)
        
        XCTAssertEqual(options.dsn, "https://c70c9b4dc4a2d887270e01ab6023eb90@o4511850822631424.ingest.us.sentry.io/4511852225757184")
        XCTAssertTrue(options.debug)
        XCTAssertTrue(options.sendDefaultPii ?? false)
        #endif
    }
}
