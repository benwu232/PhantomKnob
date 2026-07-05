import os

extension os.Logger {
    static let knob = os.Logger(subsystem: "com.phantomknob", category: "knob")
    static let multitouch = os.Logger(subsystem: "com.phantomknob", category: "multitouch")
    static let overlay = os.Logger(subsystem: "com.phantomknob", category: "overlay")
    static let statusBar = os.Logger(subsystem: "com.phantomknob", category: "statusBar")
    static let globalTouch = os.Logger(subsystem: "com.phantomknob", category: "globalTouch")
    static let app = os.Logger(subsystem: "com.phantomknob", category: "app")
    static let settings = os.Logger(subsystem: "com.phantomknob", category: "settings")
    static let cloudSync = os.Logger(subsystem: "com.phantomknob", category: "cloudSync")
    static let ruleLibrary = os.Logger(subsystem: "com.phantomknob", category: "ruleLibrary")
    static let language = os.Logger(subsystem: "com.phantomknob", category: "language")
}
