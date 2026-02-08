// Sources/asbmutil/Keychain.swift
import Foundation
import Security

struct KCBlob: Codable {
    let clientId: String
    let keyId: String
    let privateKey: String    // PEM text
    let teamId: String
}

struct ProfileInfo: Codable {
    let name: String
    let clientId: String
    let scope: String
    let createdDate: Date
}

enum Keychain {
    static let service = "com.github.rodchristiansen.asbmutil"
    static let profilesKey = "PROFILES_LIST"
    static let currentProfileKey = "CURRENT_PROFILE"

    @discardableResult
    static func saveBlob(_ blob: KCBlob, profileName: String = "default") -> OSStatus {
        let data = try! JSONEncoder().encode(blob)
        let accountName = "SBM_CREDENTIALS_\(profileName)"
        let q: [String:Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  accountName,
            kSecValueData as String:    data
        ]
        SecItemDelete(q as CFDictionary)
        
        // Update profiles list
        updateProfilesList(profileName: profileName, blob: blob)
        
        return SecItemAdd(q as CFDictionary, nil)
    }

    static func loadBlob(profileName: String = "default") -> KCBlob? {
        let accountName = "SBM_CREDENTIALS_\(profileName)"
        let q: [String:Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(KCBlob.self, from: d)
    }

    // Load blob using current profile
    static func loadBlob() -> KCBlob? {
        let currentProfile = getCurrentProfile()
        return loadBlob(profileName: currentProfile)
    }

    static func deleteBlob(profileName: String) -> OSStatus {
        let accountName = "SBM_CREDENTIALS_\(profileName)"
        let q: [String:Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName
        ]
        
        // Remove from profiles list
        removeFromProfilesList(profileName: profileName)
        
        return SecItemDelete(q as CFDictionary)
    }

    static func listProfiles() -> [ProfileInfo] {
        let q: [String:Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profilesKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data,
              let profiles = try? JSONDecoder().decode([ProfileInfo].self, from: d) else {
            return []
        }
        return profiles
    }

    static func getCurrentProfile() -> String {
        let q: [String:Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: currentProfileKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data,
              let profileName = String(data: d, encoding: .utf8) else {
            return "default"
        }
        return profileName
    }

    static func setCurrentProfile(_ profileName: String) -> OSStatus {
        let data = profileName.data(using: .utf8)!
        let q: [String:Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  currentProfileKey,
            kSecValueData as String:    data
        ]
        SecItemDelete(q as CFDictionary)
        return SecItemAdd(q as CFDictionary, nil)
    }

    private static func updateProfilesList(profileName: String, blob: KCBlob) {
        var profiles = listProfiles()
        
        // Remove existing profile with same name
        profiles.removeAll { $0.name == profileName }
        
        // Add new profile info
        let scope = blob.clientId.hasPrefix("SCHOOLAPI") ? "school.api" : "business.api"
        let newProfile = ProfileInfo(
            name: profileName,
            clientId: blob.clientId,
            scope: scope,
            createdDate: Date()
        )
        profiles.append(newProfile)
        
        // Save updated list
        saveProfilesList(profiles)
    }

    private static func removeFromProfilesList(profileName: String) {
        var profiles = listProfiles()
        profiles.removeAll { $0.name == profileName }
        saveProfilesList(profiles)
    }

    private static func saveProfilesList(_ profiles: [ProfileInfo]) {
        let data = try! JSONEncoder().encode(profiles)
        let q: [String:Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  profilesKey,
            kSecValueData as String:    data
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    // MARK: - Token Cache

    /// Save a token to the keychain for a specific profile
    @discardableResult
    static func saveToken(_ token: Token, profileName: String = "default") -> OSStatus {
        let data = try! JSONEncoder().encode(token)
        let accountName = "SBM_TOKEN_\(profileName)"
        let q: [String:Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  accountName,
            kSecValueData as String:    data
        ]
        SecItemDelete(q as CFDictionary)
        return SecItemAdd(q as CFDictionary, nil)
    }

    /// Load a cached token from the keychain for a specific profile
    static func loadToken(profileName: String = "default") -> Token? {
        let accountName = "SBM_TOKEN_\(profileName)"
        let q: [String:Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data,
              let token = try? JSONDecoder().decode(Token.self, from: d) else {
            return nil
        }
        return token
    }

    /// Delete cached token for a profile
    @discardableResult
    static func deleteToken(profileName: String = "default") -> OSStatus {
        let accountName = "SBM_TOKEN_\(profileName)"
        let q: [String:Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName
        ]
        return SecItemDelete(q as CFDictionary)
    }
}