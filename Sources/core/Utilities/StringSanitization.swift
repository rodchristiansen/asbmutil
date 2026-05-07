import Foundation

extension String {
    /// Trim leading/trailing whitespace and newlines. Apple OAuth identifiers
    /// (client_id, key_id) are single-line tokens; a stray newline from the
    /// clipboard ends up in the JWT iss/sub and the URL query, which Apple
    /// rejects as `invalid_client`.
    public var sanitizedIdentifier: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
