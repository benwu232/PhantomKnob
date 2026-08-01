import AppKit
import Foundation
import os

class URLSchemeHandler {
    static let shared = URLSchemeHandler()
    
    private init() {}
    
    func startListening() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        parseAndTriggerActivation(url: url)
    }
    
    func parseAndTriggerActivation(url: URL) {
        guard url.host == "activate" else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let key = components?.queryItems?.first(where: { $0.name == "key" || $0.name == "license_key" })?.value
        let email = components?.queryItems?.first(where: { $0.name == "email" })?.value
        
        if let key = key, let email = email {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("TriggerLicenseActivationFromURL"),
                    object: nil,
                    userInfo: ["key": key, "email": email]
                )
            }
        }
    }
}
