import Foundation
import SwiftUI
import Combine
import AudioToolbox

class UserGuideViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var isStep2Unlocked: Bool = false
    @Published var accumulatedRotation: Double = 0.0
    @Published var volumeVal: Float = 0.5
    @Published var hovered: Bool = false
    @Published var rotationAngle: Double = 0.0
    @Published var isGestureActive: Bool = false
    @Published var skipOnNextStartup: Bool = false
    
    private var tickAccumulator: Double = 0.0
    private let audioService: AudioControlService
    private var cancellables = Set<AnyCancellable>()
    private var systemSoundID: SystemSoundID = 0
    private var lastPlayTime: Double = 0
    
    init(audioService: AudioControlService = AudioControlService()) {
        self.audioService = audioService
        self.volumeVal = audioService.getVolume() ?? 0.5
        setupBindings()
        
        let soundURL = URL(fileURLWithPath: "/System/Library/Sounds/Tink.aiff")
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &systemSoundID)
    }
    
    deinit {
        if systemSoundID != 0 {
            AudioServicesDisposeSystemSoundID(systemSoundID)
        }
    }
    
    private func setupBindings() {
        NotificationCenter.default.publisher(for: NSNotification.Name("KnobPanelDidRotate"))
            .sink { [weak self] notification in
                guard let self = self, self.currentStep == 2, self.hovered else { return }
                if let delta = notification.userInfo?["delta"] as? Double {
                    self.registerRotation(delta)
                }
            }
            .store(in: &cancellables)
            
        ControlPanelViewModel.shared.$isGestureActive
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                self?.isGestureActive = active
            }
            .store(in: &cancellables)
    }
    
    func nextStep() {
        if currentStep == 2 && !isStep2Unlocked { return }
        currentStep += 1
    }
    
    func registerRotation(_ degrees: Double) {
        guard currentStep == 2 else { return }
        
        // 更新视觉旋转角度
        rotationAngle += degrees
        
        // 累加绝对值度数
        let absDeg = abs(degrees)
        accumulatedRotation += absDeg
        if accumulatedRotation >= 100.0 {
            isStep2Unlocked = true
        }
        
        // 播放 Tick 反馈嘀嗒音 (限制频率以防爆音，最高 20Hz/50ms 间隔)
        let ticks = updateTickAccumulationAndGetTicks(absDeg)
        let now = ProcessInfo.processInfo.systemUptime
        if ticks > 0 && (now - lastPlayTime) >= 0.05 {
            if systemSoundID != 0 {
                AudioServicesPlaySystemSound(systemSoundID)
            } else {
                AudioServicesPlaySystemSound(1104)
            }
            lastPlayTime = now
        }
        
        // 实时更新并同步系统音量
        let sensitivity: Float = 0.005
        let deltaValue = Float(degrees) * sensitivity
        let newVal = max(0.0, min(1.0, volumeVal + deltaValue))
        if audioService.setVolume(newVal) {
            volumeVal = newVal
        }
    }
    
    func updateTickAccumulationAndGetTicks(_ delta: Double) -> Int {
        tickAccumulator += delta
        if tickAccumulator >= 1.0 {
            let ticks = Int(tickAccumulator)
            tickAccumulator -= Double(ticks)
            return ticks
        }
        return 0
    }
    
    func getTickAccumulator() -> Double {
        return tickAccumulator
    }
    
    func completeGuide() {
        UserDefaults.standard.set(skipOnNextStartup, forKey: "skipUserGuideOnStartup")
        UserDefaults.standard.set(true, forKey: "firstRunUserGuideCompleted")
        UserGuideWindowController.shared.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            KnobPanelWindowController.shared.show()
        }
    }
}
