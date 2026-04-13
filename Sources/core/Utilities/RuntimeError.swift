import Foundation

public struct RuntimeError: Error, LocalizedError, CustomStringConvertible {
    public let description: String
    public var errorDescription: String? { description }
    public init(_ description: String) { self.description = description }
}
