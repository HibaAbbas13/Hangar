import Foundation

enum SharedConstants {
    static let appGroupId = "group.com.dev.flightdeck"
    static let bundleId = "com.dev.flightdeck"
    static let widgetBundleId = "com.dev.flightdeck.widgets"
    static let urlScheme = "flightdeck"

    enum DefaultsKey {
        static let idToken = "fd.idToken"
        static let functionsBaseURL = "fd.functionsBaseURL"
        static let widgetSnapshot = "fd.widgetSnapshot"
        static let lastTrigger = "fd.lastTrigger"
    }
}

enum AppGroupStore {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedConstants.appGroupId) ?? .standard
    }
}
