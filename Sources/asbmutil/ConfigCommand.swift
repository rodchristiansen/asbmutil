import ArgumentParser
import Security

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Store AxM credentials in macOS Keychain",
        subcommands: [Set.self, Show.self]
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
}