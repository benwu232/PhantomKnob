import Foundation

struct DetectionResult: Codable {
    let isSupported: Bool
    let timestamp: Date
    let deviceModel: String
    let macOSVersion: String
    let details: DetectionDetails
    
    struct DetectionDetails: Codable {
        let normalizedPositionAvailable: Bool
        let sampleCount: Int
        let errorMessage: String?
    }
}
