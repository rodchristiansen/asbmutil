// Sources/asbmutil/Keychain.swift
import Foundation
import Security

struct KCBlob: Codable {
    let clientId: String
    let keyId: String
    let privateKey: String    // PEM text
    let teamId: String
}

enum Keychain {
    static let service = "com.github.rodchristiansen.asbmutil"

    @discardableResult
    static func saveBlob(_ blob: KCBlob) -> OSStatus {
        let data = try! JSONEncoder().encode(blob)
        let q: [String:Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  "SBM_CREDENTIALS",
            kSecValueData as String:    data
        ]
        SecItemDelete(q as CFDictionary)
        return SecItemAdd(q as CFDictionary, nil)
    }

    static func loadBlob() -> KCBlob? {
        let q: [String:Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "SBM_CREDENTIALS",
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(KCBlob.self, from: d)
    }
}