import Foundation
import StoreKit
import UIKit

enum ReviewService {
    private static let successKey = "fd.review.successCount"
    private static let promptedVersionKey = "fd.review.promptedVersion"
    private static let lastPromptKey = "fd.review.lastPromptAt"

    
    static let successThreshold = 5
    
    static let cooldownDays = 120

    private static var defaults: UserDefaults { .standard }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    
    @MainActor
    static func registerSuccess() {
        let count = defaults.integer(forKey: successKey) + 1
        defaults.set(count, forKey: successKey)
        guard count >= successThreshold, shouldPrompt else { return }
        request()
    }

    private static var shouldPrompt: Bool {
        
        if defaults.string(forKey: promptedVersionKey) == appVersion { return false }
        if let last = defaults.object(forKey: lastPromptKey) as? Date {
            let elapsed = Date().timeIntervalSince(last) / 86_400
            if elapsed < Double(cooldownDays) { return false }
        }
        return true
    }

    @MainActor
    private static func request() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        defaults.set(appVersion, forKey: promptedVersionKey)
        defaults.set(Date(), forKey: lastPromptKey)
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    
    
    @MainActor
    static func openWriteReview() {
        guard let url = URL(string: Constants.Legal.writeReviewURL) else { return }
        UIApplication.shared.open(url)
    }
}
