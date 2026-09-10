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
    static var isAvailable: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupId
        ) != nil
    }

    static var defaults: UserDefaults {
        guard let shared = UserDefaults(suiteName: SharedConstants.appGroupId) else {
            assertionFailure("App Group \(SharedConstants.appGroupId) is unavailable. Enable it on both Hangar and HangarWidgets targets.")
            return .standard
        }
        return shared
    }

    static func persist() {
        defaults.synchronize()
    }
}
