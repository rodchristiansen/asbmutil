import Foundation

public struct Token: Codable, Sendable {
    public let access_token: String
    public let expires_in: Int
    public let token_type: String
    public let issuedAt: Date

    public var isExpired: Bool { Date() > issuedAt.addingTimeInterval(TimeInterval(expires_in - 300)) }

    private enum CodingKeys: String, CodingKey {
        case access_token, expires_in, token_type, issuedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        access_token = try container.decode(String.self, forKey: .access_token)
        expires_in = try container.decode(Int.self, forKey: .expires_in)
        token_type = try container.decode(String.self, forKey: .token_type)
        issuedAt = (try? container.decode(Date.self, forKey: .issuedAt)) ?? Date()
    }
}
