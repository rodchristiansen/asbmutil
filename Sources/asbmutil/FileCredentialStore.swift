// Sources/asbmutil/FileCredentialStore.swift
// File-based credential storage for Linux (no macOS Keychain available).
// Credentials are stored as JSON files in ~/.config/asbmutil/ with 0600 permissions.

#if !canImport(Security)
import Foundation

enum Keychain {
    static let service = "com.github.rodchristiansen.asbmutil"
    static let profilesKey = "PROFILES_LIST"
    static let currentProfileKey = "CURRENT_PROFILE"

    // MARK: - Storage directory

    private static var configDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/asbmutil")
    }

    private static func ensureConfigDir() {
        let fm = FileManager.default
        let path = configDir.path
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
            // Set directory permissions to 0700
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)
        }
    }

    private static func filePath(for account: String) -> URL {
        return configDir.appendingPathComponent("\(account).json")
    }

    private static func writeData(_ data: Data, account: String) {
        ensureConfigDir()
        let url = filePath(for: account)
        try? data.write(to: url, options: .atomic)
        // Restrict file permissions to owner-only (0600)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private static func readData(account: String) -> Data? {
        let url = filePath(for: account)
        return try? Data(contentsOf: url)
    }

    private static func deleteFile(account: String) -> Bool {
        let url = filePath(for: account)
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Blob (credentials) operations

    @discardableResult
    static func saveBlob(_ blob: KCBlob, profileName: String = "default") -> Int32 {
        let data = try! JSONEncoder().encode(blob)
        let account = "SBM_CREDENTIALS_\(profileName)"
        writeData(data, account: account)
        updateProfilesList(profileName: profileName, blob: blob)
        return 0 // success (mirrors errSecSuccess)
    }

    static func loadBlob(profileName: String = "default") -> KCBlob? {
        let account = "SBM_CREDENTIALS_\(profileName)"
        guard let data = readData(account: account) else { return nil }
        return try? JSONDecoder().decode(KCBlob.self, from: data)
    }

    static func loadBlob() -> KCBlob? {
        let currentProfile = getCurrentProfile()
        return loadBlob(profileName: currentProfile)
    }

    static func deleteBlob(profileName: String) -> Int32 {
        let account = "SBM_CREDENTIALS_\(profileName)"
        removeFromProfilesList(profileName: profileName)
        return deleteFile(account: account) ? 0 : -25300 // 0 = success, -25300 mirrors errSecItemNotFound
    }

    // MARK: - Profiles

    static func listProfiles() -> [ProfileInfo] {
        guard let data = readData(account: profilesKey) else { return [] }
        return (try? JSONDecoder().decode([ProfileInfo].self, from: data)) ?? []
    }

    static func getCurrentProfile() -> String {
        guard let data = readData(account: currentProfileKey),
              let name = String(data: data, encoding: .utf8) else {
            return "default"
        }
        return name
    }

    static func setCurrentProfile(_ profileName: String) -> Int32 {
        let data = profileName.data(using: .utf8)!
        writeData(data, account: currentProfileKey)
        return 0
    }

    private static func updateProfilesList(profileName: String, blob: KCBlob) {
        var profiles = listProfiles()
        profiles.removeAll { $0.name == profileName }
        let scope = blob.clientId.hasPrefix("SCHOOLAPI") ? "school.api" : "business.api"
        let newProfile = ProfileInfo(
            name: profileName,
            clientId: blob.clientId,
            scope: scope,
            createdDate: Date()
        )
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
        writeData(data, account: profilesKey)
    }

    // MARK: - Token Cache

    @discardableResult
    static func saveToken(_ token: Token, profileName: String = "default") -> Int32 {
        let data = try! JSONEncoder().encode(token)
        let account = "SBM_TOKEN_\(profileName)"
        writeData(data, account: account)
        return 0
    }

    static func loadToken(profileName: String = "default") -> Token? {
        let account = "SBM_TOKEN_\(profileName)"
        guard let data = readData(account: account) else { return nil }
        return try? JSONDecoder().decode(Token.self, from: data)
    }

    @discardableResult
    static func deleteToken(profileName: String = "default") -> Int32 {
        let account = "SBM_TOKEN_\(profileName)"
        return deleteFile(account: account) ? 0 : -25300
    }

    /// Clear the current-profile entry (used by config clear)
    static func clearCurrentProfileEntry() {
        _ = deleteFile(account: currentProfileKey)
    }
}
#endif
