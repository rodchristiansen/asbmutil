import Foundation

enum Creds {
    static func load() throws -> Credentials {
        guard let blob = Keychain.loadBlob() else {
            throw RuntimeError("missing keychain items – run: asbmutil config set")
        }
        let scope = blob.clientId.hasPrefix("SCHOOLAPI") ? "school.api" : "business.api"
        return Credentials(
            clientId:      blob.clientId,
            keyId:         blob.keyId,
            privateKeyPEM: blob.privateKey,
            scope:         scope
        )
    }
}