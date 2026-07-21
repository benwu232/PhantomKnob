import SwiftUI

enum FreePopoverMode: Equatable {
    case activating(secondsRemaining: Double)
    case sessionExpired
}

struct FreeEditionPopoverView: View {
    let mode: FreePopoverMode
    var onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            switch mode {
            case .activating(let seconds):
                HStack {
                    Text(String(localized: "popover.freeEdition", defaultValue: "FREE EDITION"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                        .tracking(1)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                    
                    Text(String(localized: "popover.preparing", defaultValue: "Preparing gesture environment..."))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 4)
                
                Text(String(format: String(localized: "popover.countdown", defaultValue: "Activating in %ds..."), Int(ceil(seconds))))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                    
            case .sessionExpired:
                HStack {
                    Text(String(localized: "popover.freeEdition", defaultValue: "FREE EDITION"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .tracking(1)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("🔒")
                            .font(.system(size: 14))
                        Text(String(localized: "popover.expired.title", defaultValue: "Session Expired (15m)"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(String(localized: "popover.expired.description", defaultValue: "The free edition automatically deactivated after 15 minutes. Press ⌥⌘K to activate again."))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(3)
                }
                .padding(.vertical, 2)
                
                Button(action: onUpgrade) {
                    Text(String(localized: "popover.upgrade", defaultValue: "Get Pro for Unlimited Time ➔"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 240)
        .preferredColorScheme(.dark)
    }
}
