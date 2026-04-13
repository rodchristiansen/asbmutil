// Sources/core/Auth/Credentials.swift
public struct Credentials: Sendable {
    public let clientId: String
    public let keyId: String
    public let privateKeyPEM: String
    public let scope: String            // "school.api" or "business.api"

    public init(clientId: String, keyId: String, privateKeyPEM: String, scope: String) {
        self.clientId = clientId
        self.keyId = keyId
        self.privateKeyPEM = privateKeyPEM
        self.scope = scope
    }
}
