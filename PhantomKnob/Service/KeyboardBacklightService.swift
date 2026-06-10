import Foundation

class KeyboardBacklightService {
    private var client: AnyObject?
    
    init() {
        if let bundle = Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework") {
            bundle.load()
            if let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type {
                client = clientClass.init()
            }
        }
    }
    
    func getBrightness() -> Float? {
        guard let client = client else { return nil }
        let sel = NSSelectorFromString("keyboardBrightness")
        if client.responds(to: sel) {
            if let value = client.value(forKey: "keyboardBrightness") as? Float {
                return value
            }
        }
        return nil
    }
    
    func setBrightness(_ brightness: Float) -> Bool {
        guard let client = client else { return false }
        let targetBrightness = max(0.0, min(1.0, brightness))
        let sel = NSSelectorFromString("setKeyboardBrightness:error:")
        if client.responds(to: sel) {
            client.setValue(targetBrightness, forKey: "keyboardBrightness")
            return true
        }
        return false
    }
}
