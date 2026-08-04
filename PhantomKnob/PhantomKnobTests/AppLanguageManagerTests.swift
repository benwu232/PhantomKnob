import XCTest
@testable import PhantomKnob

class AppLanguageManagerTests: XCTestCase {
    private let suiteName = "com.phantomknob.PhantomKnobTests"
    
    override func setUp() {
        super.setUp()
        UserDefaults.app = UserDefaults(suiteName: suiteName) ?? .standard
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        cleanArgumentDomain()
    }
    
    override func tearDown() {
        cleanArgumentDomain()
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        UserDefaults.app = .standard
        super.tearDown()
    }
    
    private func cleanArgumentDomain() {
        var volatileDomain = UserDefaults.app.volatileDomain(forName: "NSArgumentDomain")
        if volatileDomain["AppleLanguages"] != nil {
            volatileDomain.removeValue(forKey: "AppleLanguages")
            UserDefaults.app.setVolatileDomain(volatileDomain, forName: "NSArgumentDomain")
        }
    }
    
    func testDefaultLanguageIsSystem() {
        XCTAssertEqual(AppLanguageManager.shared.currentLanguage, .system)
    }
    
    func testSetLanguageChangesUserDefaults() {
        AppLanguageManager.shared.currentLanguage = .english
        XCTAssertEqual(AppLanguageManager.shared.currentLanguage, .english)
        XCTAssertEqual(UserDefaults.app.string(forKey: "appLanguage"), "en")
        
        let appleLangs = UserDefaults.app.stringArray(forKey: "AppleLanguages")
        XCTAssertEqual(appleLangs, ["en"])
    }
    
    func testSetLanguageToSystemRemovesAppleLanguages() {
        let originalAppleLangs = UserDefaults.app.stringArray(forKey: "AppleLanguages")
        
        AppLanguageManager.shared.currentLanguage = .chinese
        XCTAssertEqual(UserDefaults.app.stringArray(forKey: "AppleLanguages"), ["zh-Hans"])
        
        AppLanguageManager.shared.currentLanguage = .system
        XCTAssertEqual(UserDefaults.app.stringArray(forKey: "AppleLanguages"), originalAppleLangs)
    }
    
    func testApplyLanguageOverrideOnStartupRemovesAppleLanguagesFromArgumentDomain() {
        let mockDomain: [String: Any] = ["AppleLanguages": ["en"]]
        UserDefaults.app.setVolatileDomain(mockDomain, forName: "NSArgumentDomain")
        
        let initialVolatile = UserDefaults.app.volatileDomain(forName: "NSArgumentDomain")
        XCTAssertNotNil(initialVolatile["AppleLanguages"])
        
        AppLanguageManager.shared.applyLanguageOverrideOnStartup()
        
        let finalVolatile = UserDefaults.app.volatileDomain(forName: "NSArgumentDomain")
        XCTAssertNil(finalVolatile["AppleLanguages"])
    }

    func testSetLanguagePostsNotification() {
        let expectation = expectation(description: "LanguageDidChange Notification")
        let observer = NotificationCenter.default.addObserver(
            forName: AppLanguageManager.languageDidChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        
        AppLanguageManager.shared.currentLanguage = .english
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
