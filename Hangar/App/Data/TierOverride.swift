import Foundation

enum TierOverride: String, CaseIterable, Identifiable {
    case none
    case free
    case premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Real entitlement"
        case .free: return "Force Free"
        case .premium: return "Force Premium"
        }
    }

    var subtitle: String {
        switch self {
        case .none: return "Whatever RevenueCat and Firestore actually say."
        case .free: return "Locks premium features so the gates can be tested."
        case .premium: return "Unlocks every feature without a purchase."
        }
    }
}

enum TierOverrideStore {
    private static let key = "fd.debug.tierOverride"

    static var current: TierOverride {
        get {
            guard Constants.Debug.isInternalBuild else { return .none }
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let value = TierOverride(rawValue: raw) else { return .none }
            return value
        }
        set {
            guard Constants.Debug.isInternalBuild else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
