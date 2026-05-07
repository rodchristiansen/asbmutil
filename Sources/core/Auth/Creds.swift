import Foundation

public enum Creds {
    public static func load(profileName: String? = nil) throws -> Credentials {
        let profile = profileName ?? Keychain.getCurrentProfile()
        guard let blob = Keychain.loadBlob(profileName: profile) else {
            if let profileName = profileName {
                throw RuntimeError("missing keychain items for profile '\(profileName)' – run: asbmutil config set --profile \(profileName)")
            } else {
                throw RuntimeError("missing keychain items for current profile '\(profile)' – run: asbmutil config set")
            }
        }
        let cleanClientId = blob.clientId.sanitizedIdentifier
        let cleanKeyId = blob.keyId.sanitizedIdentifier
        if cleanClientId.contains(where: { $0.isNewline }) || cleanKeyId.contains(where: { $0.isNewline }) {
            throw RuntimeError("stored credentials for profile '\(profile)' contain embedded newlines (likely a paste error). Re-save them in Settings or run: asbmutil config set --profile \(profile)")
        }
        let scope = cleanClientId.hasPrefix("SCHOOLAPI") ? "school.api" : "business.api"
        return Credentials(
            clientId:      cleanClientId,
            keyId:         cleanKeyId,
            privateKeyPEM: blob.privateKey,
            scope:         scope
        )
    }
}
