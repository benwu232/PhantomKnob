import XCTest
@testable import PhantomKnob

class AppLanguageManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        super.tearDown()
    }
    
    func testDefaultLanguageIsSystem() {
        XCTAssertEqual(AppLanguageManager.shared.currentLanguage, .system)
    }
    
    func testSetLanguageChangesUserDefaults() {
        AppLanguageManager.shared.currentLanguage = .english
        XCTAssertEqual(AppLanguageManager.shared.currentLanguage, .english)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "appLanguage"), "en")
        
        let appleLangs = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
        XCTAssertEqual(appleLangs, ["en"])
    }
    
    func testSetLanguageToSystemRemovesAppleLanguages() {
        let originalAppleLangs = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
        
        AppLanguageManager.shared.currentLanguage = .chinese
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["zh-Hans"])
        
        AppLanguageManager.shared.currentLanguage = .system
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), originalAppleLangs)
    }
}
