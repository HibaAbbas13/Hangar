import Foundation
import Security

enum KeychainService {
    static func set(_ value: String, account: String, accessGroup: String? = nil) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: SharedConstants.bundleId,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppGroupStore.defaults.set(value, forKey: account)
            return
        }
        AppGroupStore.defaults.set(value, forKey: account)
        _ = accessGroup
    }

    static func get(account: String, accessGroup: String? = nil) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: SharedConstants.bundleId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        _ = accessGroup
        return AppGroupStore.defaults.string(forKey: account)
    }

    static func delete(account: String, accessGroup: String? = nil) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: SharedConstants.bundleId
        ]
        SecItemDelete(query as CFDictionary)
        AppGroupStore.defaults.removeObject(forKey: account)
        _ = accessGroup
    }
}
