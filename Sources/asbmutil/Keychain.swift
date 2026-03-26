// Sources/asbmutil/Keychain.swift
import Foundation

struct KCBlob: Codable, Sendable {
    let clientId: String
    let keyId: String
    let privateKey: String    // PEM text
    let teamId: String
}

struct ProfileInfo: Codable, Sendable {
    let name: String
    let clientId: String
    let scope: String
    let createdDate: Date
}

#if canImport(Security)
import Security

enum Keychain {
    static let service = "com.github.rodchristiansen.asbmutil"
    static let profilesKey = "PROFILES_LIST"
    static let currentProfileKey = "CURRENT_PROFILE"

    // Base query: data-protection keychain (no per-app ACLs, no prompts)
    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String:                        kSecClassGenericPassword,
            kSecAttrService as String:                  service,
            kSecAttrAccount as String:                  account,
            kSecUseDataProtectionKeychain as String:    true,
            kSecAttrAccessible as String:               kSecAttrAccessibleWhenUnlocked,
        ]
    }

    // MARK: - Credentials

    @discardableResult
    static func saveBlob(_ blob: KCBlob, profileName: String = "default") -> OSStatus {
        let data = try! JSONEncoder().encode(blob)
        let accountName = "SBM_CREDENTIALS_\(profileName)"

        // Delete legacy (file-based) and data-protection entries
        deleteLegacyItem(account: accountName)
        var q = baseQuery(account: accountName)
        SecItemDelete(q as CFDictionary)

        q[kSecValueData as String] = data
        updateProfilesList(profileName: profileName, blob: blob)
        return SecItemAdd(q as CFDictionary, nil)
    }

    static func loadBlob(profileName: String = "default") -> KCBlob? {
        let accountName = "SBM_CREDENTIALS_\(profileName)"
        var q = baseQuery(account: accountName)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let d = out as? Data {
            return try? JSONDecoder().decode(KCBlob.self, from: d)
        }
        // Fall back to legacy keychain (migrates on next save)
        return loadBlobLegacy(account: accountName)
    }

    static func loadBlob() -> KCBlob? {
        let currentProfile = getCurrentProfile()
        return loadBlob(profileName: currentProfile)
    }

    static func deleteBlob(profileName: String) -> OSStatus {
        let accountName = "SBM_CREDENTIALS_\(profileName)"
        deleteLegacyItem(account: accountName)
        removeFromProfilesList(profileName: profileName)
        let q = baseQuery(account: accountName)
        return SecItemDelete(q as CFDictionary)
    }

    // MARK: - Profiles

    static func listProfiles() -> [ProfileInfo] {
        var q = baseQuery(account: profilesKey)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let d = out as? Data,
           let profiles = try? JSONDecoder().decode([ProfileInfo].self, from: d) {
            return profiles
        }
        // Try legacy keychain
        if let d = loadLegacyData(account: profilesKey),
           let profiles = try? JSONDecoder().decode([ProfileInfo].self, from: d) {
            return profiles
        }
        return []
    }

    static func getCurrentProfile() -> String {
        var q = baseQuery(account: currentProfileKey)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let d = out as? Data,
           let name = String(data: d, encoding: .utf8) {
            return name
        }
        // Try legacy keychain
        if let d = loadLegacyData(account: currentProfileKey),
           let name = String(data: d, encoding: .utf8) {
            return name
        }
        return "default"
    }

    static func setCurrentProfile(_ profileName: String) -> OSStatus {
        let data = profileName.data(using: .utf8)!
        deleteLegacyItem(account: currentProfileKey)
        var q = baseQuery(account: currentProfileKey)
        SecItemDelete(q as CFDictionary)

        q[kSecValueData as String] = data
        return SecItemAdd(q as CFDictionary, nil)
    }

    private static func updateProfilesList(profileName: String, blob: KCBlob) {
        var profiles = listProfiles()
        profiles.removeAll { $0.name == profileName }

        let scope = blob.clientId.hasPrefix("SCHOOLAPI") ? "school.api" : "business.api"
        let newProfile = ProfileInfo(
            name: profileName, clientId: blob.clientId,
            scope: scope, createdDate: Date())
        profiles.append(newProfile)
        saveProfilesList(profiles)
    }

    private static func removeFromProfilesList(profileName: String) {
        var profiles = listProfiles()
        profiles.removeAll { $0.name == profileName }
        saveProfilesList(profiles)
    }

    private static func saveProfilesList(_ profiles: [ProfileInfo]) {
        let data = try! JSONEncoder().encode(profiles)
        deleteLegacyItem(account: profilesKey)
        var q = baseQuery(account: profilesKey)
        SecItemDelete(q as CFDictionary)

        q[kSecValueData as String] = data
        SecItemAdd(q as CFDictionary, nil)
    }

    // MARK: - Token Cache

    @discardableResult
    static func saveToken(_ token: Token, profileName: String = "default") -> OSStatus {
        let data = try! JSONEncoder().encode(token)
        let accountName = "SBM_TOKEN_\(profileName)"

        deleteLegacyItem(account: accountName)
        var q = baseQuery(account: accountName)
        SecItemDelete(q as CFDictionary)

        q[kSecValueData as String] = data
        return SecItemAdd(q as CFDictionary, nil)
    }

    static func loadToken(profileName: String = "default") -> Token? {
        let accountName = "SBM_TOKEN_\(profileName)"
        var q = baseQuery(account: accountName)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let d = out as? Data {
            return try? JSONDecoder().decode(Token.self, from: d)
        }
        return nil
    }

    @discardableResult
    static func deleteToken(profileName: String = "default") -> OSStatus {
        let accountName = "SBM_TOKEN_\(profileName)"
        deleteLegacyItem(account: accountName)
        let q = baseQuery(account: accountName)
        return SecItemDelete(q as CFDictionary)
    }

    static func clearCurrentProfileEntry() {
        deleteLegacyItem(account: currentProfileKey)
        let q = baseQuery(account: currentProfileKey)
        SecItemDelete(q as CFDictionary)
    }

    // MARK: - Legacy Migration Helpers

    /// Read from the old file-based keychain (no data-protection flag)
    private static func loadBlobLegacy(account: String) -> KCBlob? {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(KCBlob.self, from: d)
    }

    private static func loadLegacyData(account: String) -> Data? {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return d
    }

    /// Delete an item from the old file-based keychain
    private static func deleteLegacyItem(account: String) {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
#endif