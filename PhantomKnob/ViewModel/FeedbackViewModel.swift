import Foundation
import AppKit

public class FeedbackViewModel: ObservableObject {
    @Published public var isCopiedEmail: Bool = false
    @Published public var isCopiedDiagnostics: Bool = false
    
    public let supportEmail = "phantomknob232@gmail.com"
    public let gitHubIssuesURL = URL(string: "https://github.com/benwu232/PhantomKnob/issues")!
    
    public init() {}
    
    public func generateDiagnosticInfo() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let model = Host.current().localizedName ?? "Unknown Mac"
        let license = "\(LicenseManager.shared.currentState)"
        
        return """
        App: PhantomKnob v\(version) (\(build))
        macOS: \(os)
        Device: \(model)
        License: \(license)
        """
    }
    
    public func buildMailtoURL() -> URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let diagnostics = generateDiagnosticInfo()
        
        let subject = "PhantomKnob Feedback (v\(version) build \(build))"
        let body = "\n\n---\n\(diagnostics)"
        
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        return URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
    
    public func copySupportEmail() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(supportEmail, forType: .string)
        isCopiedEmail = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isCopiedEmail = false
        }
    }
    
    public func copyDiagnostics() {
        let info = generateDiagnosticInfo()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
        isCopiedDiagnostics = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isCopiedDiagnostics = false
        }
    }
    
    public func openGitHubIssues() {
        NSWorkspace.shared.open(gitHubIssuesURL)
    }
    
    public func openEmailClient() {
        if let url = buildMailtoURL() {
            NSWorkspace.shared.open(url)
        }
    }
}
