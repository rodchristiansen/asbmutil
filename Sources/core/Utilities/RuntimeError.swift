import Foundation

public struct RuntimeError: Error, LocalizedError, CustomStringConvertible {
    public let description: String
    /// The HTTP status that produced this error, when it came from an API response.
    public let statusCode: Int?
    public var errorDescription: String? { description }
    public init(_ description: String, statusCode: Int? = nil) {
        self.description = description
        self.statusCode = statusCode
    }
}
