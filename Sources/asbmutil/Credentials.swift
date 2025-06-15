// Sources/asbmutil/Credentials.swift
struct Credentials: Sendable {
    let clientId: String
    let keyId: String
    let privateKeyPEM: String
    let scope: String            // "school.api" or "business.api"
}