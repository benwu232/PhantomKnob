import AppKit
import SwiftUI

class ReleaseNotesWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class ReleaseNotesController: NSObject, NSWindowDelegate {
    static let shared = ReleaseNotesController()
    
    private var window: ReleaseNotesWindow?
    
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    var currentVersionOverride: String?
    
    var currentVersion: String {
        currentVersionOverride ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
    }
    
    func showIfNeeded() {
        // 1. Skip if user guide onboarding isn't completed
        let guideCompleted = UserDefaults.app.bool(forKey: "firstRunUserGuideCompleted")
        guard guideCompleted else { return }
        
        // 2. Check version changes
        let currentVersion = self.currentVersion
        
        // If lastSeenVersion is nil, user is running the app/feature for the first time.
        // We register the current version as read and skip showing.
        guard let lastSeenVersion = UserDefaults.app.string(forKey: "lastSeenReleaseNotesVersion") else {
            UserDefaults.app.set(currentVersion, forKey: "lastSeenReleaseNotesVersion")
            return
        }
        
        guard currentVersion != lastSeenVersion else { return }
        
        // 3. Load release notes content
        guard let notes = loadReleaseNotes(for: currentVersion) else { return }
        
        // 4. Show window
        show(version: currentVersion, title: notes.title, items: notes.items)
    }
    
    private func show(version: String, title: String, items: [String]) {
        guard window == nil else { return }
        
        let width: CGFloat = 520
        let height: CGFloat = 380
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        
        let win = ReleaseNotesWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .floating
        win.hidesOnDeactivate = true
        win.delegate = self
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20
        visualEffectView.layer?.masksToBounds = true
        
        win.contentView = visualEffectView
        
        let view = ReleaseNotesView(version: version, title: title, items: items) { [weak self] in
            UserDefaults.app.set(version, forKey: "lastSeenReleaseNotesVersion")
            self?.hide()
        }
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = visualEffectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(hostingView)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        window?.orderOut(nil)
        window = nil
    }
    
    struct ReleaseNoteModel: Decodable {
        let title: String
        let items: [String]
    }
    
    func loadReleaseNotes(for version: String) -> ReleaseNoteModel? {
        guard let url = Bundle.main.url(forResource: "release-notes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: ReleaseNoteModel].self, from: data) else {
            return nil
        }
        return dict[version]
    }
    
    func windowDidResignKey(_ notification: Notification) {
        let currentVersion = self.currentVersion
        UserDefaults.app.set(currentVersion, forKey: "lastSeenReleaseNotesVersion")
        hide()
    }
}
