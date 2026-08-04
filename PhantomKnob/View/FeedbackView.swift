import SwiftUI

public struct FeedbackView: View {
    @StateObject private var viewModel = FeedbackViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Section
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "feedback.title", defaultValue: "Send Feedback"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text(String(localized: "feedback.subtitle", defaultValue: "We'd love to hear your thoughts, feature requests, or issue reports."))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Channels Grid / Cards
            VStack(spacing: 12) {
                // GitHub Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "number.square.fill")
                                .foregroundColor(.accentColor)
                            Text(String(localized: "feedback.github.title", defaultValue: "GitHub Issues"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(String(localized: "feedback.github.description", defaultValue: "Report bugs, request features, or view existing discussions."))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        viewModel.openGitHubIssues()
                    }) {
                        Text(String(localized: "feedback.github.button", defaultValue: "Open GitHub"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Email Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text(String(localized: "feedback.email.title", defaultValue: "Email Support"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(viewModel.supportEmail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.copySupportEmail()
                        }) {
                            Text(viewModel.isCopiedEmail ? 
                                 String(localized: "feedback.copied", defaultValue: "Copied!") : 
                                 String(localized: "feedback.email.copy", defaultValue: "Copy"))
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            viewModel.openEmailClient()
                        }) {
                            Text(String(localized: "feedback.email.button", defaultValue: "Send Email"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
            }
            
            // Diagnostics Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "feedback.diagnostics.title", defaultValue: "System Diagnostics"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        viewModel.copyDiagnostics()
                    }) {
                        Label(viewModel.isCopiedDiagnostics ? 
                              String(localized: "feedback.copied", defaultValue: "Copied!") : 
                              String(localized: "feedback.diagnostics.copy", defaultValue: "Copy Info"),
                              systemImage: viewModel.isCopiedDiagnostics ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                
                Text(viewModel.generateDiagnosticInfo())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                    .cornerRadius(6)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 480, height: 380)
    }
}
