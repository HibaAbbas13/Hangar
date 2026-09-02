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
            static let lifetime = "com.dev.hangar.lifetime"
            static let proAnnual = "com.dev.hangar.pro.annual"
            static let teamMonthly = "com.dev.hangar.team.monthly"
        }
    }

    enum Monetization {
        static let paywallEnabled = true
        static let judgePromoCode = "HANGAR-JUDGE"
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

    enum Debug {
        static var isTestFlight: Bool {
            Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        }

        static var isInternalBuild: Bool {
            #if DEBUG
            true
            #else
            isTestFlight
            #endif
        }
    }

    enum Legal {
        static let appStoreId = "0000000000"
        static let privacyURL = "https://flightdeck.dev/privacy"
        static let termsURL = "https://flightdeck.dev/terms"
        static let supportEmail = "support@flightdeck.dev"
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
