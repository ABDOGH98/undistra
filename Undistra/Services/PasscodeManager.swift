import CryptoKit
import Foundation
import Security

/// Keeps a salted SHA-256 hash of the passcode in the Keychain. The passcode itself is never stored.
struct PasscodeManager {
    private let service = "com.miy33t.Undistra"
    private let account = "passcode"

    var hasPasscode: Bool { readItem() != nil }

    func save(_ code: String) throws {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        let stored = salt + hash(code, salt: salt)
        try writeItem(stored)
    }

    func verify(_ code: String) -> Bool {
        guard let stored = readItem(), stored.count > 16 else { return false }
        let salt = stored.prefix(16)
        return stored.dropFirst(16) == hash(code, salt: Data(salt))
    }

    private func hash(_ code: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(code.utf8)))
    }

    // MARK: Keychain

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private func readItem() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func writeItem(_ data: Data) throws {
        let update = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainError.status(update) }
        var add = baseQuery
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    enum KeychainError: LocalizedError {
        case status(OSStatus)
        var errorDescription: String? {
            if case .status(let s) = self {
                return "Keychain error \(s): \(SecCopyErrorMessageString(s, nil) as String? ?? "unknown")"
            }
            return nil
        }
    }
}
