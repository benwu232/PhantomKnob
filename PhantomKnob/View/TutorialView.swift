import SwiftUI

class TutorialViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var isStep2Unlocked: Bool = false
    @Published var accumulatedRotation: Double = 0.0
    
    func nextStep() {
        if currentStep == 2 && !isStep2Unlocked { return }
        currentStep += 1
    }
    
    func registerRotation(_ degrees: Double) {
        guard currentStep == 2 else { return }
        accumulatedRotation += abs(degrees)
        if accumulatedRotation >= 360.0 {
            isStep2Unlocked = true
        }
    }
    
    func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "firstRunTutorialCompleted")
        KnobPanelWindowController.shared.hide()
    }
}

struct TutorialView: View {
    @StateObject var tutorialVM = TutorialViewModel()
    @EnvironmentObject var controlPanelVM: ControlPanelViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if tutorialVM.currentStep == 1 {
                VStack(spacing: 16) {
                    Text("欢迎使用 PhantomKnob!")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("通过在触控板上旋转双指来直接调节音量、屏幕亮度和键盘灯。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("双击状态栏上的小圆圈图标，或者按 ⌥Space 快捷键可以呼出/关闭控制面板。")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button("开始新手引导") {
                        tutorialVM.nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else if tutorialVM.currentStep == 2 {
                VStack(spacing: 16) {
                    Text("手势练习（旋转满 360°）")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("将鼠标移入下方的某个调节盘上，然后放置两指在触控板上进行旋转。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ProgressView(value: min(tutorialVM.accumulatedRotation, 360.0), total: 360.0)
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                    
                    Text("已完成: \(Int(min(tutorialVM.accumulatedRotation, 360.0)))° / 360°")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Button("下一步") {
                        tutorialVM.nextStep()
                    }
                    .disabled(!tutorialVM.isStep2Unlocked)
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    Text("恭喜，您已完成新手教学！")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("当面板显示时，手势优先改变选中的调节项；当面板隐藏时，手势将控制光标下任意应用的滑块。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button("开启 PhantomKnob") {
                        tutorialVM.completeTutorial()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("KnobPanelDidRotate"))) { notification in
            if let delta = notification.userInfo?["delta"] as? Double {
                tutorialVM.registerRotation(delta)
            }
        }
    }
}
