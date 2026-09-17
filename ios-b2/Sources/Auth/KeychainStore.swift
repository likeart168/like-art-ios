import Foundation
import Security
import LocalAuthentication

enum KeychainStore {
    // Generic passwords use kSecClassGenericPassword + kSecAttrAccount.
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.likeart.app.session",
        kSecAttrAccount as String: "auth_token"
    ]
    static func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }

    private static var biometricQuery: [String: Any] {
        var q = query
        q[kSecAttrAccount as String] = "biometric_auth_token"
        return q
    }
    static func enrollBiometrics(_ token: String) throws {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        var q = biometricQuery
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessControl as String] = access
        SecItemDelete(biometricQuery as CFDictionary)
        let result = SecItemAdd(q as CFDictionary, nil)
        guard result == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result)) }
        clear()
        UserDefaults.standard.set(true, forKey: "biometric")
    }
    static func unlockBiometrics(context: LAContext) throws -> String {
        var q = biometricQuery
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        q[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return token
    }
    static func clearBiometrics() {
        SecItemDelete(biometricQuery as CFDictionary)
        UserDefaults.standard.set(false, forKey: "biometric")
    }
}
