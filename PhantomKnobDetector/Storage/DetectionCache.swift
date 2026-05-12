import Foundation

class DetectionCache {
    private let cacheKey = "com.phantomknob.detectionResult"
    private let userDefaults = UserDefaults.standard
    
    func save(_ result: DetectionResult) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(result) {
            userDefaults.set(data, forKey: cacheKey)
        }
    }
    
    func load() -> DetectionResult? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DetectionResult.self, from: data)
    }
    
    func clear() {
        userDefaults.removeObject(forKey: cacheKey)
    }
}
