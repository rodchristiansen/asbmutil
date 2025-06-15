import Foundation

enum HTTPMethod: String, Sendable { case GET, POST }

struct Request<T: Decodable>: Sendable {
    let method: HTTPMethod
    let path: String
    let scope: String
    let body: Data?
}
