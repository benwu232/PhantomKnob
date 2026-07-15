import SwiftUI

struct KnobPanelView: View {
    @EnvironmentObject var viewModel: ControlPanelViewModel
    @AppStorage("firstRunTutorialCompleted") private var firstRunTutorialCompleted = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                HUDCircleButton(icon: "xmark", color: .white.opacity(0.7)) {
                    KnobPanelWindowController.shared.hide()
                }
                
                Spacer()
                
                Text(String(localized: "panel.title", defaultValue: "PhantomKnob 快捷面板"))
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                
                Spacer()
                
                HUDCircleButton(
                    icon: viewModel.isPinned ? "pin.fill" : "pin",
                    color: viewModel.isPinned ? .orange : .white.opacity(0.6)
                ) {
                    viewModel.isPinned.toggle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
            
            mainControlLayout
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !firstRunTutorialCompleted {
                firstRunTutorialCompleted = true
            }
        }
    }
    
    private var mainControlLayout: some View {
        HStack(spacing: 40) {
            RadialKnobControlView(
                title: String(localized: "knob.title.volume", defaultValue: "System Volume"),
                icon: "speaker.wave.3.fill",
                value: viewModel.volumeVal,
                angle: viewModel.rotationAngles[.volume, default: 0.0],
                isFocused: viewModel.focusedVariable == .volume,
                isGestureActive: viewModel.isGestureActive
            )
            .onHover { isHover in
                viewModel.setHoverTarget(isHover ? .volume : nil)
            }
            
            RadialKnobControlView(
                title: String(localized: "knob.title.brightness", defaultValue: "Screen Brightness"),
                icon: "sun.max.fill",
                value: viewModel.brightnessVal,
                angle: viewModel.rotationAngles[.brightness, default: 0.0],
                isFocused: viewModel.focusedVariable == .brightness,
                isGestureActive: viewModel.isGestureActive
            )
            .onHover { isHover in
                viewModel.setHoverTarget(isHover ? .brightness : nil)
            }
            
            RadialKnobControlView(
                title: String(localized: "knob.title.backlight", defaultValue: "Keyboard Backlight"),
                icon: "keyboard.fill",
                value: viewModel.backlightVal,
                angle: viewModel.rotationAngles[.keyboardBacklight, default: 0.0],
                isFocused: viewModel.focusedVariable == .keyboardBacklight,
                isGestureActive: viewModel.isGestureActive
            )
            .onHover { isHover in
                viewModel.setHoverTarget(isHover ? .keyboardBacklight : nil)
            }
        }
        .padding(.horizontal, 40)
    }
}

struct RadialKnobControlView: View {
    let title: String
    let icon: String
    let value: Float
    let angle: Double
    let isFocused: Bool
    let isGestureActive: Bool
    let showPercentage: Bool
    
    init(title: String, icon: String, value: Float, angle: Double, isFocused: Bool, isGestureActive: Bool, showPercentage: Bool = true) {
        self.title = title
        self.icon = icon
        self.value = value
        self.angle = angle
        self.isFocused = isFocused
        self.isGestureActive = isGestureActive
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Glow circle
                Circle()
                    .stroke(Color.blue.opacity(isFocused ? 0.3 : 0.05), lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .blur(radius: isFocused ? 4 : 0)
                
                // Progress arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(value))
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                      )
                    .frame(width: 104, height: 104)
                    .rotationEffect(Angle(degrees: -90))
                
                // Inner dial circle
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 90, height: 90)
                    .shadow(radius: isFocused ? 8 : 2)
                
                // Indicator dot
                if isFocused && isGestureActive {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .offset(y: -38)
                        .rotationEffect(Angle(degrees: angle))
                }
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isFocused ? .blue : .white.opacity(0.8))
            }
            
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            
            if showPercentage {
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .scaleEffect(isFocused ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
    }
}
