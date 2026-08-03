import Foundation

extension UserDefaults {
    private static var _app: UserDefaults = .standard
    
    /// The UserDefaults instance to be used across the application.
    /// Defaults to `.standard`, but can be redirected to an isolated suite in unit tests.
    public static var app: UserDefaults {
        get { _app }
        set { _app = newValue }
    }

    /// Whether to restore the active state of PhantomKnob on application startup.
    public var restoreActiveStateOnStartup: Bool {
        get { object(forKey: "restoreActiveStateOnStartup") as? Bool ?? true }
        set { set(newValue, forKey: "restoreActiveStateOnStartup") }
    }

    /// The last persistent active state of PhantomKnob.
    public var lastKnobActiveState: Bool {
        get { bool(forKey: "lastKnobActiveState") }
        set { set(newValue, forKey: "lastKnobActiveState") }
    }
}
