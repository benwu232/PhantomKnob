import SwiftUI

struct UserGuideView: View {
    @StateObject private var viewModel = UserGuideViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                if viewModel.currentStep == 1 {
                    Text("第一步：设备检测与基础旋转")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("检测触控板硬件支持并练习音量旋转手势")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else if viewModel.currentStep == 2 {
                    Text("第二步：三种旋钮对比与深度定制")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("练习双环与无极变速旋钮的精细调节、键盘微调及 HUD 定制")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("第三步：开启全局旋钮控制")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("了解激活热键、快捷方式及适配软件列表")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Content
            Group {
                if viewModel.currentStep == 1 {
                    step1View
                } else if viewModel.currentStep == 2 {
                    step2View
                } else {
                    step3View
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Footer (Navigation)
            HStack {
                if viewModel.currentStep > 1 {
                    Button(action: {
                        withAnimation {
                            viewModel.currentStep -= 1
                        }
                    }) {
                        Text("上一步")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if viewModel.currentStep < 3 {
                    Button(action: {
                        withAnimation {
                            viewModel.nextStep()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("下一步")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: viewModel.currentStep == 1 && !viewModel.isTouchpadDetected
                                    ? [Color(white: 1.0, opacity: 0.1), Color(white: 1.0, opacity: 0.1)]
                                    : [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: Color.blue.opacity(viewModel.currentStep == 1 && !viewModel.isTouchpadDetected ? 0 : 0.3), radius: 4, y: 2)
                    }
                    .disabled(viewModel.currentStep == 1 && !viewModel.isTouchpadDetected)
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        viewModel.completeGuide()
                    }) {
                        Text("开启全局控制")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.emerald],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                            .shadow(color: Color.green.opacity(0.3), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 725, height: 575)
    }
    
    // MARK: - Step 1: Device test & Volume practice
    private var step1View: some View {
        VStack(spacing: 16) {
            Text("请在触控板上练习使用旋钮手势：\n将鼠标移动到音量旋钮上，然后在触控板上用两指做旋转的动作。")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 16)
            
            ZStack {
                RadialKnobControlView(
                    title: "音量练习旋钮",
                    icon: "speaker.wave.3.fill",
                    value: viewModel.volumeVal,
                    angle: viewModel.rotationAngle,
                    isFocused: viewModel.hovered,
                    isGestureActive: viewModel.isGestureActive,
                    showPercentage: true
                )
                .onHover { isHover in
                    viewModel.hovered = isHover
                    viewModel.hoveredKnob = isHover ? .volumeKnob : .none
                }
                
                if !viewModel.hovered && !viewModel.isTouchpadDetected {
                    CursorGuideAnimationView()
                        .offset(x: 70, y: -50)
                        .transition(.opacity)
                }
            }
            .frame(height: 140)
            
            HStack(spacing: 8) {
                if viewModel.isTouchpadDetected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    Text("✅ 触控板检测成功！您的设备完美支持。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                    Text("正在等待两指旋转动作以检测设备 (信号样本: \(viewModel.touchpadSamplesCount)/3)...")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Knob comparison, multipliers, HUD trigger
    private var step2View: some View {
        VStack(spacing: 8) {
            // Keyboard multiplier display
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle.fill")
                    Text("键盘倍率微调: \(String(format: "%.1fx", viewModel.currentMultiplier))")
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.amber.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            // Side-by-side self-drawn knobs
            HStack(spacing: 60) {
                // Double Ring Knob
                VStack(spacing: 8) {
                    ZStack {
                        OverlayView(
                            targetName: "双环旋钮",
                            valueText: String(format: "%.1f", viewModel.doubleKnobVal),
                            angle: viewModel.doubleKnobAngle,
                            isDeadzone: false,
                            scale: viewModel.doubleKnobBaseMultiplier * viewModel.currentMultiplier,
                            themeColorHex: AppSettings.shared.defaultThemeColor,
                            overlayStyle: AppSettings.shared.defaultOverlayStyle,
                            rotationStyle: AppSettings.shared.defaultRotationStyle,
                            diameter: viewModel.doubleKnobDiameter
                        )
                        .onHover { isHover in
                            viewModel.hoveredKnob = isHover ? .doubleKnob : .none
                        }
                    }
                    .frame(height: 340)
                    
                    Text("双环（外环0.1倍，内环1.0倍）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text("根据手指距离自动切换微调/粗调")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        triggerCustomizer(for: "DoubleKnob")
                    }) {
                        Text("定制此旋钮")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                // Linear Knob
                VStack(spacing: 8) {
                    ZStack {
                        OverlayView(
                            targetName: "无极变速旋钮",
                            valueText: String(format: "%.1f", viewModel.linearKnobVal),
                            angle: viewModel.linearKnobAngle,
                            isDeadzone: false,
                            scale: viewModel.linearKnobBaseMultiplier * viewModel.currentMultiplier,
                            themeColorHex: AppSettings.shared.defaultThemeColor,
                            overlayStyle: AppSettings.shared.defaultOverlayStyle,
                            rotationStyle: AppSettings.shared.defaultRotationStyle,
                            diameter: viewModel.linearKnobDiameter
                        )
                        .onHover { isHover in
                            viewModel.hoveredKnob = isHover ? .linearKnob : .none
                        }
                    }
                    .frame(height: 340)
                    
                    Text("无极变速（0.1 ~ 5.0倍）")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text("变速步长随手势物理半径无极缩放")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        triggerCustomizer(for: "LinearKnob")
                    }) {
                        Text("定制此旋钮")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
            
            // Instruction Box
            VStack(alignment: .leading, spacing: 3) {
                Text("💡 使用键盘方向键微调倍率")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text("• 旋转中按 ↑/↓ 增减 1.0x，按 ←/→ 增减 0.1x，按数字键 2-9 直接相乘。")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                Text("• 在旋钮上旋转时，按下键盘“C”键可以直接呼出应用内置定制面板。")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: Global intro & Confirm
    private var step3View: some View {
        VStack(spacing: 20) {
            Text("Phantom Knob 已准备就绪！")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.green)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "command")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全局激活热键：⌘ ⌥ R (Command + Option + R)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("在任何有滑动条、步进器或适配控件上，按下此快捷键或在菜单栏开启后，即可通过旋钮手势调节。")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "option")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("临时暂停手势：按住 Option 键")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("如果您只是想正常使用触控板原生滚动或捏合缩放，可以按住 Option 键临时忽略旋钮手势。")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("深度支持的剪辑与多媒体软件")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text("应用已经针对 CapCut (剪映)、QuickTime Player 等主流调色及剪辑软件的时间轴/音量/数值项进行了高保真适配。")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Toggle("下次启动不再显示使用引导", isOn: $viewModel.skipOnNextStartup)
                .toggleStyle(.checkbox)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 12))
            
            Spacer()
        }
    }
    
    // MARK: - Customizer Trigger Helper
    private func triggerCustomizer(for knobType: String) {
        let target = DetectedTarget(
            bundleID: "com.phantomknob.controlpanel",
            axRole: "ControlPanel",
            identifier: knobType,
            displayName: knobType == "DoubleKnob" ? "双环旋钮" : "无极变速旋钮",
            element: nil,
            parentChain: []
        )
        CustomizerHUDWindowController.shared.show(for: target)
    }
}

struct CursorGuideAnimationView: View {
    @State private var pulse = false
    
    var body: some View {
        Image(systemName: "hand.draw.fill")
            .font(.system(size: 32))
            .foregroundColor(Color.blue.opacity(0.8))
            .scaleEffect(pulse ? 1.2 : 0.9)
            .offset(x: pulse ? -10 : 10, y: pulse ? 10 : -10)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// Color asset helpers to avoid styling compilation errors
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
}
