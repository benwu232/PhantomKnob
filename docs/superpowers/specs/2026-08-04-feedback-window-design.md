# Feedback Window & Multi-Channel Feedback Support Design

## Overview
This design document defines the implementation of a native SwiftUI Feedback Window (`FeedbackView` + `FeedbackWindowController`) for PhantomKnob, replacing the simplistic `mailto:` action in `StatusBarController.swift`. The new Feedback Window provides multiple support channels (GitHub Issues, Email) alongside one-click copy actions for support email and formatted system diagnostics.

---

## User Goals & Requirements
1. **Multi-Channel Access**:
   - **GitHub Issues**: Direct link to `https://github.com/benwu232/PhantomKnob/issues` for bug reports and feature requests.
   - **Email Support**: Native `mailto:phantomknob232@gmail.com` launch pre-filled with app and system details.
2. **Copy Fallbacks**:
   - Provide an explicit "Copy Email Address" button for users without a configured default macOS Mail client.
   - Provide a "Copy Diagnostic Info" button to easily attach device and environment details to GitHub issues or external messages.
3. **Native macOS UX**:
   - Clean, lightweight SwiftUI interface running inside a dedicated `NSWindow` managed by `FeedbackWindowController`.
   - Accessible directly from the status bar menu (`Send Feedback…`).

---

## Architecture & Components

### 1. `FeedbackWindowController` (`Service/FeedbackWindowController.swift`)
- **Type**: Singleton `NSWindowController` subclass or wrapper (similar to `SettingsWindowController` / `UserGuideWindowController`).
- **Responsibilities**:
  - Lazily instantiates and presents a titled, closable `NSWindow` containing `FeedbackView`.
  - Centers the window on screen and brings it to focus when `show()` is called.
  - Ensures only a single instance of the feedback window exists.

### 2. `FeedbackView` (`View/FeedbackView.swift`)
- **Type**: SwiftUI `View`
- **Sections**:
  - **Header**: Icon, Title ("Feedback" / "发送反馈"), and subtitle description.
  - **Channel Cards**:
    - **GitHub Tile**: "Open GitHub Issues" button -> opens `https://github.com/benwu232/PhantomKnob/issues` via `NSWorkspace.shared.open`.
    - **Email Tile**: 
      - "Send Email" button -> opens prefilled `mailto:phantomknob232@gmail.com?subject=...&body=...`.
      - "Copy Email Address" button -> copies `phantomknob232@gmail.com` to `NSPasteboard.general` with visual feedback ("Copied!").
  - **Diagnostic Info Panel**:
    - Text box displaying preformatted diagnostics:
      ```text
      App: PhantomKnob v{version} ({build})
      macOS: {osVersion}
      Device: {deviceModel}
      License: {licenseState}
      ```
    - "Copy Diagnostic Info" button -> copies formatted string to `NSPasteboard.general`.

### 3. `StatusBarController` (`Service/StatusBarController.swift`)
- Modify `#selector(sendFeedback)` to call `FeedbackWindowController.shared.show()`.

### 4. Localization (`Localizable.xcstrings`)
- Add localized strings for:
  - Window Title & Subtitle
  - Channel labels & buttons ("Open GitHub Issues", "Send Email", "Copy Email Address", "Copy Diagnostic Info")
  - Diagnostic labels and status toasts ("Copied!")

---

## Verification Plan

### Automated Unit Tests
- `PhantomKnobTests/FeedbackWindowControllerTests.swift`:
  - Test `FeedbackWindowController.shared.show()` creates window and sets frontmost focus.
  - Test diagnostic info text generator produces non-empty string with App Version, macOS version, and License state.
  - Test mailto URL construction helper logic.

### Manual Verification
1. **Menu Trigger**: Click `Send Feedback…` in status bar menu. Confirm `FeedbackWindow` opens centered and focused.
2. **GitHub Link**: Click "Open GitHub Issues". Verify system default browser opens `https://github.com/benwu232/PhantomKnob/issues`.
3. **Send Email**: Click "Send Email". Verify system Mail app opens prefilled mailto link with subject and body.
4. **Copy Email**: Click "Copy Email Address". Paste into TextEdit or browser to confirm `phantomknob232@gmail.com` was copied, and verify "Copied!" feedback is shown.
5. **Copy Diagnostics**: Click "Copy Diagnostic Info". Paste to confirm formatted system information block.
6. **Localization Check**: Switch app language (English / Chinese) and confirm all UI strings render correctly.
