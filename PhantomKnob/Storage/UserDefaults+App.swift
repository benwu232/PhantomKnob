import Foundation

extension UserDefaults {
    private static var _app: UserDefaults = .standard
    
    /// The UserDefaults instance to be used across the application.
    /// Defaults to `.standard`, but can be redirected to an isolated suite in unit tests.
    public static var app: UserDefaults {
        get { _app }
        set { _app = newValue }
    }
}
