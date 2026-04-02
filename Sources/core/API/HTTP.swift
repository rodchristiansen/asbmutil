import Foundation

public enum HTTPMethod: String, Sendable { case GET, POST }

public struct Request<T: Decodable>: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let scope: String
    public let body: Data?

    public init(method: HTTPMethod, path: String, scope: String, body: Data?) {
        self.method = method
        self.path = path
        self.scope = scope
        self.body = body
    }
}
