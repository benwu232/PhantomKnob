import Foundation
#if canImport(Sentry)
import Sentry
#endif

public enum SentryManager {
    public static let dsn = "https://c70c9b4dc4a2d887270e01ab6023eb90@o4511850822631424.ingest.us.sentry.io/4511852225757184"
    
    #if canImport(Sentry)
    public static func configureOptions(_ options: Options) {
        options.dsn = dsn
        options.debug = true
        options.sendDefaultPii = true
        options.environment = "production"
        options.sampleRate = 1.0
        options.enableAutoSessionTracking = true
        options.attachStacktrace = true
        options.beforeSend = { event in
            let optOut = UserDefaults.app.bool(forKey: "disableCrashReporting")
            return optOut ? nil : event
        }
    }
    #endif
    
    public static func start() {
        #if canImport(Sentry)
        SentrySDK.start { options in
            configureOptions(options)
        }
        #endif
    }
}
