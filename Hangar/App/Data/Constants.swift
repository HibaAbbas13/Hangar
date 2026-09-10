import Foundation

enum Constants {
    static let appName = "Hangar"
    static let bundleId = SharedConstants.bundleId
    static let appGroupId = SharedConstants.appGroupId
    static let urlScheme = SharedConstants.urlScheme

    enum RevenueCat {
        static let entitlementId = "hangar_pro"
        static let infoPlistKey = "REVENUECAT_API_KEY"

        enum Product {
            static let supporter = "com.dev.hangar.supporter"
            static let groundCrew = "com.dev.hangar.groundcrew"
        }
    }

    enum Monetization {
        static let paywallEnabled = true
        static let freeTrialDays = 7
    }

    enum Limits {
        static let freeDeckCount = 1
        static let freeButtonCount = 3
    }

    enum Firestore {
        static let users = "users"
        static let decks = "decks"
        static let buttons = "buttons"
        static let activity = "activity"
        static let members = "members"
        static let profiles = "profiles"
        static let sharedDecks = "sharedDecks"
        static let invites = "invites"
        static let inviteCodes = "inviteCodes"
    }

    enum Functions {
        static let upsertButton = "upsertButton"
        static let triggerDeckButton = "triggerDeckButton"
        static let triggerDeckButtonHttp = "triggerDeckButtonHttp"
        static let getButtonSecret = "getButtonSecret"
        static let runExecutionProfile = "runExecutionProfile"
        static let createInvite = "createInvite"
        static let joinDeck = "joinDeck"
        static let revokeInvite = "revokeInvite"
        static let syncPremium = "syncPremium"
        static let regionInfoKey = "FUNCTIONS_REGION"
        static let defaultRegion = "us-central1"
    }

    enum Crypto {
        static let encryptedPrefix = "enc:v1:"
    }

    enum Demo {
        static let emailInfoKey = "DEMO_EMAIL"
        static let passwordInfoKey = "DEMO_PASSWORD"
        static let callsign = "Operator"
        static let seedFlagPrefix = "fd.sampleSeeded."
        static let autoHangarFlag = "fd.autoSampleHangar"

        static var email: String {
            string(from: emailInfoKey)
        }

        static var password: String {
            string(from: passwordInfoKey)
        }

        static var isConfigured: Bool {
            email.isEmpty == false && password.isEmpty == false
        }

        private static func string(from key: String) -> String {
            let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if value.hasPrefix("$(") || value.contains("YOUR_") { return "" }
            return value
        }
    }

    /// The demo account from `DEMO_EMAIL` in Secrets.xcconfig is Premium on
    /// every build, including App Store, so review and local testing do not
    /// depend on a sandbox purchase. Leave `DEMO_EMAIL` empty in public
    /// example configs so clones do not ship an allowlist.
    enum Access {
        static func isAlwaysPremium(_ email: String?) -> Bool {
            guard let email, !email.isEmpty else { return false }
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let demo = Constants.Demo.email.lowercased()
            return demo.isEmpty == false && normalized == demo
        }
    }

    enum Debug {
        static var isInternalBuild: Bool {
            #if DEBUG
            true
            #else
            false
            #endif
        }
    }

    enum Legal {
        static let appStoreId = "6806856067"
        /// Public copies of the documents that ship inside the app.
        /// Hosted from `web/` at hangar-legal.vercel.app. See `web/README.md`.
        private static let siteRoot = "https://hangar-legal.vercel.app"
        static let privacyURL = "\(siteRoot)/privacy"
        static let termsURL = "\(siteRoot)/terms"
        /// For the App Store Connect "Support URL" field. In the app itself
        /// support is a mailto — a person with a broken deploy wants to write
        /// to someone, not read a page.
        static let supportURL = "\(siteRoot)/support"
        static let supportEmail = "hibaabbas1306@gmail.com"
        static let lastUpdated = "29 August 2026"

        static var writeReviewURL: String {
            "https://apps.apple.com/app/id\(appStoreId)?action=write-review"
        }
    }

    enum Widget {
        static let controlKind = "HangarControlWidget"
        static let lockKind = "HangarLockWidget"
        static let liveActivity = "WebhookActivity"
    }
}
