import AppKit
import Foundation

class TouchpadDetector: NSObject, TouchpadEventDelegate {
    private(set) var isSupported: Bool?
    private var sampleCount: Int = 0
    private let requiredSamples = 3
    private var lastSampleTime: Date?
    private let sampleInterval: TimeInterval = 0.5
    
    var onDetectionComplete: ((DetectionResult) -> Void)?
    var onProgress: ((Int) -> Void)?
    
    override init() {
        super.init()
    }
    
    func onTouchesBegan(_ touches: Set<NSTouch>) {
        checkNormalizedPosition(touches)
    }
    
    func onTouchesMoved(_ touches: Set<NSTouch>) {
        checkNormalizedPosition(touches)
    }
    
    func onTouchesEnded(_ touches: Set<NSTouch>) {
    }
    
    private func checkNormalizedPosition(_ touches: Set<NSTouch>) {
        guard touches.count >= 2 else { return }
        
        let now = Date()
        
        if let lastTime = lastSampleTime {
            guard now.timeIntervalSince(lastTime) < sampleInterval else {
                sampleCount = 0
                return
            }
        }
        
        var allValid = true
        for touch in touches {
            let pos = touch.normalizedPosition
            let isValid = !pos.x.isNaN && !pos.y.isNaN &&
                          pos.x >= 0 && pos.x <= 1 &&
                          pos.y >= 0 && pos.y <= 1
            if !isValid {
                allValid = false
                break
            }
        }
        
        if allValid {
            sampleCount += 1
            lastSampleTime = now
            onProgress?(sampleCount)
            
            if sampleCount >= requiredSamples {
                let result = createResult(isSupported: true, normalizedAvailable: true)
                onDetectionComplete?(result)
            }
        }
    }
    
    func createResult(isSupported: Bool, normalizedAvailable: Bool) -> DetectionResult {
        let deviceModel = getDeviceModel()
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        
        return DetectionResult(
            isSupported: isSupported,
            timestamp: Date(),
            deviceModel: deviceModel,
            macOSVersion: macOSVersion,
            details: DetectionResult.DetectionDetails(
                normalizedPositionAvailable: normalizedAvailable,
                sampleCount: sampleCount,
                errorMessage: isSupported ? nil : "无法获取触摸绝对坐标"
            )
        )
    }
    
    private func getDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    func reset() {
        sampleCount = 0
        lastSampleTime = nil
        isSupported = nil
    }
}
