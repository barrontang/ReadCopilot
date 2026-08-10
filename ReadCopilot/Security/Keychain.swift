import Foundation
import Security

// MARK: - Keychain 封装
// 两个 BYOK key 只存 Keychain,不进 UserDefaults / 明文文件。

enum KeychainKey: String {
    case wereadAPIKey = "com.readcopilot.weread.apikey"   // wrk-...
    case llmAPIKey    = "com.readcopilot.llm.apikey"      // sk-... 等
    case llmBaseURL   = "com.readcopilot.llm.baseurl"     // 兼容自定义 endpoint
    case llmModel     = "com.readcopilot.llm.model"
}

struct Keychain {
    static func set(_ value: String, for key: KeychainKey) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func get(_ key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll() {
        [.wereadAPIKey, .llmAPIKey, .llmBaseURL, .llmModel].forEach { delete($0) }
    }
}
