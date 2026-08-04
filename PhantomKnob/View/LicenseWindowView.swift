import SwiftUI

struct LicenseWindowView: View {
    @State private var licenseState: LicenseState = LicenseManager.shared.currentState
    @State private var email: String = ""
    @State private var licenseKey: String = ""
    @State private var isActivating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showManualForm: Bool = false
    
    private func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return email }
        let name = String(parts[0])
        let domain = String(parts[1])
        return name.count <= 2 ? "\(name.prefix(1))***@\(domain)" : "\(name.prefix(1))***\(name.suffix(1))@\(domain)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部关闭与装饰栏
            HStack {
                Button(action: {
                    LicenseWindowController.shared.hide()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if isActivating {
                activatingStateView
            } else {
                switch licenseState {
                case .licensed:
                    licensedStateView
                case .free, .trialing:
                    unlicensedStateView
                }
            }
        }
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            self.licenseState = LicenseManager.shared.currentState
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LicenseWindowDidShow"))) { _ in
            self.licenseState = LicenseManager.shared.currentState
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LicenseStateDidChange"))) { _ in
            self.licenseState = LicenseManager.shared.currentState
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerLicenseActivationFromURL"))) { notification in
            if let key = notification.userInfo?["key"] as? String,
               let email = notification.userInfo?["email"] as? String {
                self.licenseKey = key
                self.email = email
                triggerActivation()
            }
        }
    }
    
    // 正在激活状态
    private var activatingStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("正在验证授权协议，请稍候...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }
    
    // 已激活 Pro 版状态
    private var licensedStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)
            
            Text("✨ Pro 激活成功")
                .font(.system(size: 18, weight: .bold))
            
            if let savedEmail = UserDefaults.app.string(forKey: "proLicenseEmail") {
                Text(String(format: String(localized: "license.boundEmail.format", defaultValue: "已绑定邮箱: %@"), maskEmail(savedEmail)))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("感谢您支持 PhantomKnob 的开发！所有 Pro 特权均已生效。")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button(action: {
                LicenseManager.shared.deactivate()
            }) {
                Text("解绑当前设备")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
    }
    
    // 未激活 (免费版/试用版) 状态
    private var unlicensedStateView: some View {
        VStack(spacing: 12) {
            Text("升级 PhantomKnob Pro")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.orange)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.orange)
                    Text("无限活跃会话时间 (15分钟自动断开限制已移除)")
                }
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.orange)
                    Text("瞬时启动控制模式 (移除 2 秒等待时间)")
                }
            }
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            
            Button(action: {
                NSWorkspace.shared.open(AppSettings.storeCheckoutURL)
            }) {
                Text("🛒 立即获取 Pro 授权")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            if showManualForm {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField(String(localized: "license.field.email", defaultValue: "购买邮箱"), text: $email)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                        
                        SecureField(String(localized: "license.field.key", defaultValue: "授权码 Key"), text: $licenseKey)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Button(String(localized: "license.button.manualActivate", defaultValue: "手动激活")) {
                              triggerActivation()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(String(localized: "license.button.cancel", defaultValue: "取消")) {
                            showManualForm = false
                            errorMessage = nil
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 48)
                .transition(.opacity)
            } else {
                Button(String(localized: "license.button.enterCodeManually", defaultValue: "手动输入授权码...")) {
                    withAnimation {
                        showManualForm = true
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
    
    private func triggerActivation() {
        guard !email.isEmpty && !licenseKey.isEmpty else {
            errorMessage = String(localized: "license.error.emptyFields", defaultValue: "请完整输入邮箱和授权码")
            return
        }
        isActivating = true
        errorMessage = nil
        LicenseManager.shared.activateOnline(licenseKey: licenseKey.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines)) { success, error in
            isActivating = false
            if !success {
                errorMessage = error ?? String(localized: "license.error.failed", defaultValue: "激活验证失败")
            }
        }
    }
}
