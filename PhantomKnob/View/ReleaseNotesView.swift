import SwiftUI

struct ReleaseNotesView: View {
    let version: String
    let title: String
    let items: [String]
    
    @State private var dontShowAgain = false
    
    var onDismiss: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(String(format: String(localized: "release.version.format", defaultValue: "Version %@"), version))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 28)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 16, weight: .bold))
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Footer
            HStack {
                Toggle(String(localized: "release.dontShowAgain", defaultValue: "Don't show this version again"), isOn: $dontShowAgain)
                    .toggleStyle(.checkbox)
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 12))
                
                Spacer()
                
                Button(action: {
                    onDismiss(dontShowAgain)
                }) {
                    Text(String(localized: "release.button.gotIt", defaultValue: "Got it"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 380)
        .background(Color.clear)
    }
}

struct ReleaseNotesView_Previews: PreviewProvider {
    static var previews: some View {
        ReleaseNotesView(
            version: "1.0",
            title: "Welcome to PhantomKnob!",
            items: [
                "🎛️ Global knob control with two-finger rotation gesture",
                "🎬 Pro knob packs for DaVinci Resolve, Final Cut Pro, and Logic Pro",
                "⚡ Three knob modes: Fixed, Double-Ring, and Variable Speed",
                "🔧 Full customization with Customizer HUD"
            ]
        ) { _ in }
        .background(Color.black.opacity(0.8))
    }
}
