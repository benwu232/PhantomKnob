import XCTest
@testable import PhantomKnobDetector

final class StorageTests: XCTestCase {
    
    func testSaveAndLoad() {
        let cache = DetectionCache()
        let details = DetectionResult.DetectionDetails(
            normalizedPositionAvailable: true,
            sampleCount: 3,
            errorMessage: nil
        )
        let result = DetectionResult(
            isSupported: true,
            timestamp: Date(),
            deviceModel: "MacBookPro18,3",
            macOSVersion: "macOS 14.0",
            details: details
        )
        
        cache.save(result)
        let loaded = cache.load()
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.isSupported, result.isSupported)
        XCTAssertEqual(loaded?.deviceModel, result.deviceModel)
        XCTAssertEqual(loaded?.macOSVersion, result.macOSVersion)
    }
    
    func testLoadNonExistent() {
        let cache = DetectionCache()
        cache.clear()
        
        let loaded = cache.load()
        XCTAssertNil(loaded)
    }
    
    func testClear() {
        let cache = DetectionCache()
        let details = DetectionResult.DetectionDetails(
            normalizedPositionAvailable: true,
            sampleCount: 3,
            errorMessage: nil
        )
        let result = DetectionResult(
            isSupported: true,
            timestamp: Date(),
            deviceModel: "MacBookPro18,3",
            macOSVersion: "macOS 14.0",
            details: details
        )
        
        cache.save(result)
        cache.clear()
        
        let loaded = cache.load()
        XCTAssertNil(loaded)
    }
    
    func testCodableWithDate() {
        let cache = DetectionCache()
        let testDate = Date(timeIntervalSince1970: 1234567890)
        let details = DetectionResult.DetectionDetails(
            normalizedPositionAvailable: true,
            sampleCount: 3,
            errorMessage: nil
        )
        let result = DetectionResult(
            isSupported: true,
            timestamp: testDate,
            deviceModel: "MacBookPro18,3",
            macOSVersion: "macOS 14.0",
            details: details
        )
        
        cache.save(result)
        let loaded = cache.load()
        
        XCTAssertNotNil(loaded)
        if let loaded = loaded {
            XCTAssertEqual(loaded.timestamp.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }
}
