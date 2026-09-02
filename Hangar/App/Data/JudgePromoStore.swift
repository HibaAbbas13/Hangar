import Foundation

enum JudgePromoStore {
    private static let key = "fd.promo.hangarProUnlocked"

    static var isUnlocked: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func unlock() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    
    static func matches(_ raw: String) -> Bool {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "-")
        let expected = Constants.Monetization.judgePromoCode
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "-")
        return normalized == expected
    }
}
