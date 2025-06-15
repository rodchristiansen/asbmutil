import Foundation

struct Token: Decodable, Sendable {
    let access_token: String
    let expires_in: Int
    let token_type: String

    private let issuedAt = Date()
    var isExpired: Bool { Date() > issuedAt.addingTimeInterval(TimeInterval(expires_in - 300)) }

    private enum CodingKeys: String, CodingKey {
        case access_token, expires_in, token_type
    }
}
