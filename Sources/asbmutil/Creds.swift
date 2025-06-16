import Foundation

enum Creds {
    static func load(profileName: String? = nil) throws -> Credentials {
        let profile = profileName ?? Keychain.getCurrentProfile()
        guard let blob = Keychain.loadBlob(profileName: profile) else {
            if let profileName = profileName {
                throw RuntimeError("missing keychain items for profile '\(profileName)' – run: asbmutil config set --profile \(profileName)")
            } else {
                throw RuntimeError("missing keychain items for current profile '\(profile)' – run: asbmutil config set")
            }
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