import os

extension Logger {
    static let knob = Logger(subsystem: "com.phantomknob", category: "knob")
    static let multitouch = Logger(subsystem: "com.phantomknob", category: "multitouch")
    static let overlay = Logger(subsystem: "com.phantomknob", category: "overlay")
    static let statusBar = Logger(subsystem: "com.phantomknob", category: "statusBar")
    static let globalTouch = Logger(subsystem: "com.phantomknob", category: "globalTouch")
    static let app = Logger(subsystem: "com.phantomknob", category: "app")
    static let settings = Logger(subsystem: "com.phantomknob", category: "settings")
    static let cloudSync = Logger(subsystem: "com.phantomknob", category: "cloudSync")
    static let ruleLibrary = Logger(subsystem: "com.phantomknob", category: "ruleLibrary")
    static let language = Logger(subsystem: "com.phantomknob", category: "language")
}
