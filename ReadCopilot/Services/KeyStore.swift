import Foundation

// MARK: - Key 存取协议
// 包装 Keychain 使服务可注入测试替身，避免单测依赖真实钥匙串。

protocol KeyStore {
    func get(_ key: KeychainKey) -> String?
}

struct KeychainKeyStore: KeyStore {
    func get(_ key: KeychainKey) -> String? {
        Keychain.get(key)
    }
}

/// 测试/预览用内存实现
final class InMemoryKeyStore: KeyStore {
    private var storage: [KeychainKey: String]

    init(_ storage: [KeychainKey: String] = [:]) {
        self.storage = storage
    }

    func get(_ key: KeychainKey) -> String? {
        storage[key]
    }
}
