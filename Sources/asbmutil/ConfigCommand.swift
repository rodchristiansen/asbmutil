import ArgumentParser
import Security
import Foundation

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Store AxM credentials in macOS Keychain",
        subcommands: [Set.self, Show.self, Clear.self, ListProfiles.self, SetProfile.self, ShowProfile.self]
    )

    struct Set: ParsableCommand {
        @Option var clientId: String
        @Option var keyId: String
        @Option var pemPath: String
        @Option(name: .customLong("profile"), help: "Profile name to store credentials under")
        var profileName: String = "default"
        
        func run() throws {
            let pem = try String(contentsOfFile: pemPath)
            let blob = KCBlob(clientId: clientId, keyId: keyId, privateKey: pem, teamId: "")
            guard Keychain.saveBlob(blob, profileName: profileName) == errSecSuccess else {
                throw RuntimeError("keychain write failed")
            }
            
            // Set as current profile if it's the first one or explicitly requested
            let profiles = Keychain.listProfiles()
            if profiles.count == 1 || profileName != "default" {
                _ = Keychain.setCurrentProfile(profileName)
            }
            
            print("saved credentials for profile '\(profileName)'")
        }
    }

    struct Show: ParsableCommand {
        @Option(name: .customLong("profile"), help: "Profile name to show credentials for")
        var profileName: String?
        
        func run() throws {
            let profile = profileName ?? Keychain.getCurrentProfile()
            guard let b = Keychain.loadBlob(profileName: profile) else {
                throw RuntimeError("no credentials set for profile '\(profile)'")
            }
            print("Profile: \(profile)")
            print("SBM_CLIENT_ID=\(b.clientId)")
            print("SBM_KEY_ID=\(b.keyId)")
            print("PRIVATE_KEY=[\(b.privateKey.prefix(30))…]")
        }
    }

    struct Clear: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove stored credentials from macOS Keychain"
        )
        
        @Option(name: .customLong("profile"), help: "Profile name to clear (default: all profiles)")
        var profileName: String?
        
        func run() throws {
            if let profileName = profileName {
                let status = Keychain.deleteBlob(profileName: profileName)
                switch status {
                case errSecSuccess:
                    print("credentials cleared for profile '\(profileName)'")
                case errSecItemNotFound:
                    print("no credentials found for profile '\(profileName)'")
                default:
                    throw RuntimeError("keychain delete failed with status: \(status)")
                }
            } else {
                // Clear all profiles
                let profiles = Keychain.listProfiles()
                for profile in profiles {
                    _ = Keychain.deleteBlob(profileName: profile.name)
                }
                
                // Clear current profile setting
                let q: [String:Any] = [
                    kSecClass as String:       kSecClassGenericPassword,
                    kSecAttrService as String: Keychain.service,
                    kSecAttrAccount as String: Keychain.currentProfileKey
                ]
                SecItemDelete(q as CFDictionary)
                
                print("cleared all profiles")
            }
        }
    }

    struct ListProfiles: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list-profiles",
            abstract: "List all stored credential profiles"
        )
        
        func run() throws {
            let profiles = Keychain.listProfiles()
            let currentProfile = Keychain.getCurrentProfile()
            
            if profiles.isEmpty {
                print("no profiles found")
                return
            }
            
            print("Available profiles:")
            for profile in profiles.sorted(by: { $0.name < $1.name }) {
                let current = profile.name == currentProfile ? " (current)" : ""
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                print("  \(profile.name)\(current) - \(profile.scope) - created \(formatter.string(from: profile.createdDate))")
            }
        }
    }

    struct SetProfile: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set-profile",
            abstract: "Set the current active profile"
        )
        
        @Argument var profileName: String
        
        func run() throws {
            let profiles = Keychain.listProfiles()
            guard profiles.contains(where: { $0.name == profileName }) else {
                throw RuntimeError("profile '\(profileName)' not found. Available profiles: \(profiles.map(\.name).joined(separator: ", "))")
            }
            
            guard Keychain.setCurrentProfile(profileName) == errSecSuccess else {
                throw RuntimeError("failed to set current profile")
            }
            
            print("current profile set to '\(profileName)'")
        }
    }

    struct ShowProfile: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show-profile",
            abstract: "Show the current active profile"
        )
        
        func run() throws {
            let currentProfile = Keychain.getCurrentProfile()
            let profiles = Keychain.listProfiles()
            
            if let profile = profiles.first(where: { $0.name == currentProfile }) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                print("Current profile: \(profile.name)")
                print("Scope: \(profile.scope)")
                print("Client ID: \(profile.clientId)")
                print("Created: \(formatter.string(from: profile.createdDate))")
            } else {
                print("Current profile: \(currentProfile) (not found in profiles list)")
            }
        }
    }
}