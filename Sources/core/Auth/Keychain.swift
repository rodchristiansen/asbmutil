// Sources/core/Auth/Keychain.swift
import Foundation

public struct KCBlob: Codable, Sendable {
    public let clientId: String
    public let keyId: String
    public let privateKey: String    // PEM text
    public let teamId: String

    public init(clientId: String, keyId: String, privateKey: String, teamId: String) {
        self.clientId = clientId
        self.keyId = keyId
        self.privateKey = privateKey
        self.teamId = teamId
    }
}

public struct ProfileInfo: Codable, Sendable {
    public let name: String
    public let clientId: String
    public let scope: String
    public let createdDate: Date

    public init(name: String, clientId: String, scope: String, createdDate: Date) {
        self.name = name
        self.clientId = clientId
        self.scope = scope
        self.createdDate = createdDate
    }
}

#if canImport(Security)
import Security

public enum Keychain {
    public static let service = "com.github.rodchristiansen.asbmutil"
    public static let profilesKey = "PROFILES_LIST"
    public static let currentProfileKey = "CURRENT_PROFILE"

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
    public static func saveBlob(_ blob: KCBlob, profileName: String = "default") -> OSStatus {
        let data = try! JSONEncoder().encode(blob)
        let accountName = "SBM_CREDENTIALS_\(profileName)"

        // Delete legacy (file-based) and data-protection entries
        deleteLegacyItem(account: accountName)
        var q = baseQuery(account: accountName)
        SecItemDelete(q as CFDictionary)

        q[kSecValueData as String] = data
        updateProfilesList(profileName: profileName, blob: blob)
        let status = SecItemAdd(q as CFDictionary, nil)
        if status != errSecSuccess {
            // Keychain failed (CI, headless, sandbox) -- fall back to file
            saveBlobToFile(blob, profileName: profileName)
            return errSecSuccess
        }
        return status
    }

    public static func loadBlob(profileName: String = "default") -> KCBlob? {
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
        if let blob = loadBlobLegacy(account: accountName) {
            return blob
        }
        // Fall back to file-based cache
        return loadBlobFromFile(profileName: profileName)
    }

    public static func loadBlob() -> KCBlob? {
        let currentProfile = getCurrentProfile()
        return loadBlob(profileName: currentProfile)
    }

    public static func deleteBlob(profileName: String) -> OSStatus {
        let accountName = "SBM_CREDENTIALS_\(profileName)"
        deleteLegacyItem(account: accountName)
        removeFromProfilesList(profileName: profileName)
        let q = baseQuery(account: accountName)
        return SecItemDelete(q as CFDictionary)
    }

    // MARK: - Profiles

    public static func listProfiles() -> [ProfileInfo] {
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
        // Fall back to file-based cache
        return loadProfilesListFromFile() ?? []
    }

    public static func getCurrentProfile() -> String {
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
        // Fall back to file-based cache
        return loadCurrentProfileFromFile() ?? "default"
    }

    @discardableResult
    public static func setCurrentProfile(_ profileName: String) -> OSStatus {
        let data = profileName.data(using: .utf8)!
        deleteLegacyItem(account: currentProfileKey)
        var q = baseQuery(account: currentProfileKey)
        SecItemDelete(q as CFDictionary)

        q[kSecValueData as String] = data
        let status = SecItemAdd(q as CFDictionary, nil)
        if status != errSecSuccess {
            saveCurrentProfileToFile(profileName)
            return errSecSuccess
        }
        return status
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
        let status = SecItemAdd(q as CFDictionary, nil)
        if status != errSecSuccess {
            saveProfilesListToFile(profiles)
        }
    }

    // MARK: - Token Cache (with file fallback for CI/headless)

    private static var tokenCacheDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/asbmutil")
    }

    private static func tokenFilePath(profileName: String) -> URL {
        tokenCacheDir.appendingPathComponent("SBM_TOKEN_\(profileName).json")
    }

    private static func saveTokenToFile(_ token: Token, profileName: String) {
        let dir = tokenCacheDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let data = try! JSONEncoder().encode(token)
        let url = tokenFilePath(profileName: profileName)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func loadTokenFromFile(profileName: String) -> Token? {
        guard let data = try? Data(contentsOf: tokenFilePath(profileName: profileName)) else { return nil }
        return try? JSONDecoder().decode(Token.self, from: data)
    }

    // MARK: - File fallback helpers for credentials/profiles

    private static func saveBlobToFile(_ blob: KCBlob, profileName: String) {
        let dir = tokenCacheDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let data = try! JSONEncoder().encode(blob)
        let url = dir.appendingPathComponent("SBM_CREDENTIALS_\(profileName).json")
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func loadBlobFromFile(profileName: String) -> KCBlob? {
        let url = tokenCacheDir.appendingPathComponent("SBM_CREDENTIALS_\(profileName).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(KCBlob.self, from: data)
    }

    private static func saveProfilesListToFile(_ profiles: [ProfileInfo]) {
        let dir = tokenCacheDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let data = try! JSONEncoder().encode(profiles)
        let url = dir.appendingPathComponent("\(profilesKey).json")
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func loadProfilesListFromFile() -> [ProfileInfo]? {
        let url = tokenCacheDir.appendingPathComponent("\(profilesKey).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ProfileInfo].self, from: data)
    }

    private static func saveCurrentProfileToFile(_ profileName: String) {
        let dir = tokenCacheDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let data = profileName.data(using: .utf8)!
        let url = dir.appendingPathComponent("\(currentProfileKey).json")
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func loadCurrentProfileFromFile() -> String? {
        let url = tokenCacheDir.appendingPathComponent("\(currentProfileKey).json")
        guard let data = try? Data(contentsOf: url),
              let name = String(data: data, encoding: .utf8) else { return nil }
        return name
    }

    @discardableResult
    public static func saveToken(_ token: Token, profileName: String = "default") -> OSStatus {
        let data = try! JSONEncoder().encode(token)
        let accountName = "SBM_TOKEN_\(profileName)"

        deleteLegacyItem(account: accountName)
        var q = baseQuery(account: accountName)
        SecItemDelete(q as CFDictionary)

        q[kSecValueData as String] = data
        let status = SecItemAdd(q as CFDictionary, nil)
        if status != errSecSuccess {
            // Keychain failed (CI, headless, sandbox) -- fall back to file
            saveTokenToFile(token, profileName: profileName)
        }
        return status
    }

    public static func loadToken(profileName: String = "default") -> Token? {
        let accountName = "SBM_TOKEN_\(profileName)"
        var q = baseQuery(account: accountName)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var out: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
           let d = out as? Data,
           let t = try? JSONDecoder().decode(Token.self, from: d) {
            return t
        }
        // Fall back to file-based cache
        return loadTokenFromFile(profileName: profileName)
    }

    @discardableResult
    public static func deleteToken(profileName: String = "default") -> OSStatus {
        let accountName = "SBM_TOKEN_\(profileName)"
        deleteLegacyItem(account: accountName)
        let q = baseQuery(account: accountName)
        return SecItemDelete(q as CFDictionary)
    }

    public static func clearCurrentProfileEntry() {
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
