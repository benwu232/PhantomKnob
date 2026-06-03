import SwiftUI

struct SettingsView: View {
    @AppStorage("globalSensitivity") private var globalSensitivity = 1.0
    @AppStorage("sliderSensitivity") private var sliderSensitivity: Double?
    @AppStorage("progressSensitivity") private var progressSensitivity: Double?
    
    @State private var hasAccessibilityPermission = false
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                globalSensitivity: $globalSensitivity,
                hasAccessibilityPermission: $hasAccessibilityPermission
            )
            .tabItem {
                Label("通用", systemImage: "gear")
            }
            
            SensitivitySettingsView(
                globalSensitivity: $globalSensitivity,
                sliderSensitivity: $sliderSensitivity,
                progressSensitivity: $progressSensitivity
            )
            .tabItem {
                Label("灵敏度", systemImage: "slider.horizontal.3")
            }
            
            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            hasAccessibilityPermission = AXIsProcessTrusted()
        }
    }
}

struct GeneralSettingsView: View {
    @Binding var globalSensitivity: Double
    @Binding var hasAccessibilityPermission: Bool
    
    var body: some View {
        Form {
            Section("快捷键") {
                HStack {
                    Text("全局控制开关")
                    Spacer()
                    Text("⌘⇧K")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Section("辅助功能权限") {
                HStack {
                    Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .red)
                    
                    Text(hasAccessibilityPermission ? "已授权" : "未授权")
                    
                    Spacer()
                    
                    if !hasAccessibilityPermission {
                        Button("打开系统设置") {
                            openAccessibilityPreferences()
                        }
                    }
                }
            }
            
            Section("全局灵敏度") {
                VStack(alignment: .leading) {
                    Slider(value: $globalSensitivity, in: 0.1...2.0, step: 0.1)
                    Text("每度旋转改变 \(globalSensitivity, specifier: "%.1f") 单位值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

struct SensitivitySettingsView: View {
    @Binding var globalSensitivity: Double
    @Binding var sliderSensitivity: Double?
    @Binding var progressSensitivity: Double?
    
    @State private var useCustomSliderSensitivity = false
    @State private var useCustomProgressSensitivity = false
    
    var body: some View {
        Form {
            Section("按控件类型覆盖") {
                Toggle("滑块控件", isOn: $useCustomSliderSensitivity)
                
                if useCustomSliderSensitivity {
                    Slider(value: Binding(
                        get: { sliderSensitivity ?? globalSensitivity },
                        set: { sliderSensitivity = $0 }
                    ), in: 0.1...2.0, step: 0.1)
                }
                
                Toggle("进度条", isOn: $useCustomProgressSensitivity)
                
                if useCustomProgressSensitivity {
                    Slider(value: Binding(
                        get: { progressSensitivity ?? globalSensitivity },
                        set: { progressSensitivity = $0 }
                    ), in: 0.1...2.0, step: 0.1)
                }
            }
        }
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Phantom Knob Detector")
                .font(.title)
            
            Text("版本 1.0")
                .foregroundColor(.secondary)
            
            Text("使用两指旋转手势控制任意应用中的滑块和进度条")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
