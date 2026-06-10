import SwiftUI

struct UserGuideView: View {
    @StateObject private var viewModel = UserGuideViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.currentStep == 1 {
                VStack(spacing: 20) {
                    Text("欢迎使用 PhantomKnob")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("这是一个革命性的音量与亮度调节工具。只需将双指放置在触控板上轻轻旋转，即可优雅地掌控您的系统变量。")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        Text("开始练习")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            } else if viewModel.currentStep == 2 {
                VStack(spacing: 12) {
                    Text(viewModel.hovered ? "非常棒！开始在触控板上双指旋转" : "请将光标移动到音量旋钮上")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .animation(.easeInOut, value: viewModel.hovered)
                    
                    ZStack {
                        RadialKnobControlView(
                            title: "音量调节练习",
                            icon: "speaker.wave.3.fill",
                            value: viewModel.volumeVal,
                            angle: viewModel.rotationAngle,
                            isFocused: viewModel.hovered,
                            isGestureActive: viewModel.hovered
                        )
                        .onHover { isHover in
                            viewModel.hovered = isHover
                        }
                        
                        if !viewModel.hovered {
                            // 手指在旋钮周围浮动指引的动画
                            CursorGuideAnimationView()
                                .offset(x: 40, y: -40)
                                .transition(.opacity)
                        }
                    }
                    .frame(height: 170)
                    
                    VStack(spacing: 4) {
                        ProgressView(value: min(viewModel.accumulatedRotation, 100.0), total: 100.0)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        
                        Text("已旋转: \(Int(min(viewModel.accumulatedRotation, 100.0)))° / 100°")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        Text("下一步")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(viewModel.isStep2Unlocked ? Color.blue : Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .disabled(!viewModel.isStep2Unlocked)
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 16) {
                    Text("掌握成功！")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("您可以通过快捷键 ⌘⌥R 或状态栏菜单的“切换控制模式”开启全局旋钮控制。激活后，把鼠标悬浮在任何滑块上并双指旋转即可调整。")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                        
                        Text("注意：适配后的应用程序可以获得最完美的旋转反馈体验。")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("适配列表包含：")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack(spacing: 16) {
                            Text("• CapCut (剪映)")
                            Text("• QuickTime Player")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 30)
                    
                    Button(action: {
                        viewModel.completeGuide()
                    }) {
                        Text("开启体验")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CursorGuideAnimationView: View {
    @State private var pulse = false
    
    var body: some View {
        Image(systemName: "hand.draw.fill")
            .font(.system(size: 32))
            .foregroundColor(.blue.opacity(0.8))
            .scaleEffect(pulse ? 1.2 : 0.9)
            .offset(x: pulse ? -10 : 10, y: pulse ? 10 : -10)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
