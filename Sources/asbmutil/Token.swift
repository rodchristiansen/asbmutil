import Foundation

struct Token: Codable, Sendable {
    let access_token: String
    let expires_in: Int
    let token_type: String
    let issuedAt: Date

    var isExpired: Bool { Date() > issuedAt.addingTimeInterval(TimeInterval(expires_in - 300)) }

    private enum CodingKeys: String, CodingKey {
        case access_token, expires_in, token_type, issuedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        access_token = try container.decode(String.self, forKey: .access_token)
        expires_in = try container.decode(Int.self, forKey: .expires_in)
        token_type = try container.decode(String.self, forKey: .token_type)
        issuedAt = (try? container.decode(Date.self, forKey: .issuedAt)) ?? Date()
    }
}
