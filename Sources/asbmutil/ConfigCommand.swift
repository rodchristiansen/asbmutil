import ArgumentParser
import Security

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Store AxM credentials in macOS Keychain",
        subcommands: [Set.self, Show.self, Clear.self]
    )

    struct Set: ParsableCommand {
        @Option var clientId: String
        @Option var keyId: String
        @Option var pemPath: String
        func run() throws {
            let pem = try String(contentsOfFile: pemPath)
            let blob = KCBlob(clientId: clientId, keyId: keyId, privateKey: pem, teamId: "")
            guard Keychain.saveBlob(blob) == errSecSuccess else {
                throw RuntimeError("keychain write failed")
            }
            print("saved")
        }
    }

    struct Show: ParsableCommand {
        func run() throws {
            guard let b = Keychain.loadBlob() else {
                throw RuntimeError("no credentials set")
            }
            print("SBM_CLIENT_ID=\(b.clientId)")
            print("SBM_KEY_ID=\(b.keyId)")
            print("PRIVATE_KEY=[\(b.privateKey.prefix(30))…]")
        }
    }

    struct Clear: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove stored credentials from macOS Keychain"
        )
        
        func run() throws {
            let q: [String:Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String: Keychain.service,
                kSecAttrAccount as String: "SBM_CREDENTIALS"
            ]
            
            let status = SecItemDelete(q as CFDictionary)
            
            switch status {
            case errSecSuccess:
                print("credentials cleared")
            case errSecItemNotFound:
                print("no credentials found to clear")
            default:
                throw RuntimeError("keychain delete failed with status: \(status)")
            }
        }
    }
}