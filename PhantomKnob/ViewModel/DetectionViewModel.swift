import Foundation
import SwiftUI
import Combine

class DetectionViewModel: ObservableObject {
    @Published var isDetecting: Bool = false
    @Published var progress: Int = 0
    @Published var remainingTime: Int = 30
    @Published var statusMessage: String = "请在触控板上双指触摸"
    
    private let detector = TouchpadDetector()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    let timeout: TimeInterval = 30
    
    init() {
        setupDetector()
    }
    
    private func setupDetector() {
        detector.onProgress = { [weak self] count in
            DispatchQueue.main.async {
                self?.progress = count
                self?.statusMessage = "检测中... (\(count)/3)"
            }
        }
        
        detector.onDetectionComplete = { [weak self] result in
            DispatchQueue.main.async {
                self?.stopDetection()
                NotificationCenter.default.post(
                    name: Notification.Name("DetectionComplete"),
                    object: nil,
                    userInfo: ["result": result]
                )
            }
        }
    }
    
    func startDetection() {
        isDetecting = true
        progress = 0
        remainingTime = Int(timeout)
        statusMessage = "请在触控板上双指触摸"
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingTime -= 1
            if self.remainingTime <= 0 {
                self.handleTimeout()
            }
        }
    }
    
    func stopDetection() {
        timer?.invalidate()
        timer = nil
        isDetecting = false
    }
    
    func cancelDetection() {
        stopDetection()
        NotificationCenter.default.post(name: Notification.Name("DetectionCancelled"), object: nil)
    }
    
    private func handleTimeout() {
        stopDetection()
        statusMessage = "检测超时,请重试"
        
        let result = detector.createResult(isSupported: false, normalizedAvailable: false)
        NotificationCenter.default.post(
            name: Notification.Name("DetectionComplete"),
            object: nil,
            userInfo: ["result": result]
        )
    }
    
    func handleTouchesBegan(_ touches: Set<NSTouch>) {
        detector.onTouchesBegan(touches)
    }
    
    func handleTouchesMoved(_ touches: Set<NSTouch>) {
        detector.onTouchesMoved(touches)
    }
    
    func handleTouchesEnded(_ touches: Set<NSTouch>) {
        detector.onTouchesEnded(touches)
    }
}