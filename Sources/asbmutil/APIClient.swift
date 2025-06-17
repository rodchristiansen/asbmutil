import Foundation
import CryptoKit

// --- disable system proxy for all requests ---
private let plainSession: URLSession = {
    let cfg = URLSessionConfiguration.default
    cfg.connectionProxyDictionary = [:]      // ← disable auto-proxy / PAC
    return URLSession(configuration: cfg)
}()

private let formAllowed: CharacterSet = {
    var s = CharacterSet.alphanumerics
    s.insert(charactersIn: "-._~")      // RFC 3986 unreserved
    return s
}()

actor APIClient {
    private var token: Token
    private let creds: Credentials
    private let session: URLSession = plainSession  // use proxy-free session
    
    // Retry configuration
    private let maxRetries = 3
    private let baseDelaySeconds: Double = 1.0
    private let maxDelaySeconds: Double = 60.0

    init(credentials: Credentials) async throws {
        creds = credentials
        token = try await Self.fetchToken(creds, session: session)
    }

    private func makeURL(path: String, query: [URLQueryItem] = []) -> URL {
        var comp = URLComponents()
        comp.scheme = "https"
        comp.host   = Endpoints.base(for: creds.scope).host
        comp.path   = path
        comp.queryItems = query.isEmpty ? nil : query
        return comp.url!
    }

    private func fetchOrgDevicesPage(cursor: String?, limit: Int? = nil) async throws -> OrgDevicesResponse {
        var query: [URLQueryItem] = []
        if let c = cursor { query.append(URLQueryItem(name: "cursor", value: c)) }
        if let l = limit { query.append(URLQueryItem(name: "limit", value: String(l))) }

        let url = makeURL(path: "/v1/orgDevices", query: query)

        let req = Request<OrgDevicesResponse>(
            method: HTTPMethod.GET,
            path: url.path + "?" + (url.query ?? ""),   // host comes from send()
            scope: creds.scope,
            body: nil)
        return try await send(req)
    }

    func listDevices(limit: Int? = nil) async throws -> [DeviceAttributes] {
        var cursor: String? = nil
        var page = 1
        var totalDevices = 0
        var out: [DeviceAttributes] = []

        repeat {
            let r = try await fetchOrgDevicesPage(cursor: cursor, limit: limit)
            let pageDeviceCount = r.data.count
            totalDevices += pageDeviceCount
            
            let limitInfo = limit.map { " (limit: \($0))" } ?? ""
            FileHandle.standardError.write(Data("Page \(page): found \(pageDeviceCount) devices\(limitInfo), total so far: \(totalDevices)\n".utf8))
            
            out += r.data.map(\.attributes)
            cursor = r.meta?.paging.nextCursor
            page += 1
            
            // Add a small delay between requests to be respectful to the API
            if cursor != nil {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        } while cursor != nil

        FileHandle.standardError.write(Data("Pagination complete: \(totalDevices) total devices across \(page - 1) pages\n".utf8))
        return out
    }

    func assign(serials: [String], toService serviceId: String) async throws -> ActivityDetails {
        return try await createDeviceActivity(
            activityType: "ASSIGN_DEVICES",
            serials: serials,
            serviceId: serviceId
        )
    }

    func createDeviceActivity(activityType: String, serials: [String], serviceId: String) async throws -> ActivityDetails {
        struct ActivityResponse: Decodable {
            let data: ActivityData
            struct ActivityData: Decodable {
                let id: String
                let type: String
                let attributes: ActivityAttributes
                struct ActivityAttributes: Decodable {
                    let status: String?
                    let activityType: String?
                    let createdDateTime: String?
                    let updatedDateTime: String?
                }
            }
        }
        
        let devices = serials.map { serial in
            ["type": "orgDevices", "id": serial]
        }
        
        let requestBody: [String: Any] = [
            "data": [
                "type": "orgDeviceActivities",
                "attributes": [
                    "activityType": activityType
                ],
                "relationships": [
                    "mdmServer": [
                        "data": [
                            "type": "mdmServers",
                            "id": serviceId
                        ]
                    ],
                    "devices": [
                        "data": devices
                    ]
                ]
            ]
        ]
        
        let body = try JSONSerialization.data(withJSONObject: requestBody)
        let response: ActivityResponse = try await send(
            Request(
                method: .POST,
                path: Endpoints.orgDeviceActivities.path,
                scope: creds.scope,
                body: body
            )
        )
        
        // Get server details for enhanced response
        let servers = try await listMdmServers()
        let serverDetails = servers.first { $0.id == serviceId }
        
        return ActivityDetails(
            id: response.data.id,
            activityType: response.data.attributes.activityType ?? activityType,
            status: response.data.attributes.status ?? "PENDING",
            createdDateTime: response.data.attributes.createdDateTime ?? "",
            updatedDateTime: response.data.attributes.updatedDateTime ?? "",
            deviceCount: serials.count,
            deviceSerials: serials,
            mdmServerName: serverDetails?.serverName,
            mdmServerType: serverDetails?.serverType,
            mdmServerId: serviceId
        )
    }

    func batchStatus(id: String) async throws -> String {
        return try await activityStatus(id: id)
    }

    func activityStatus(id: String) async throws -> String {
        struct Status: Decodable {
            let data: StatusData
            struct StatusData: Decodable {
                let attributes: StatusAttributes
                struct StatusAttributes: Decodable {
                    let status: String
                }
            }
        }
        let response: Status = try await send(
            Request(
                method: .GET,
                path: Endpoints.orgDeviceActivity(id).path,
                scope: creds.scope,
                body: nil
            )
        )
        return response.data.attributes.status
    }

    func listMdmServers() async throws -> [MdmServerWithId] {
        let response: MdmServersResponse = try await send(
            Request(
                method: .GET,
                path: Endpoints.mdmServers.path,
                scope: creds.scope,
                body: nil
            )
        )
        return response.data.map { server in
            MdmServerWithId(
                id: server.id,
                serverName: server.attributes.serverName,
                serverType: server.attributes.serverType,
                createdDateTime: server.attributes.createdDateTime,
                updatedDateTime: server.attributes.updatedDateTime
            )
        }
    }

    func getAssignedMdm(deviceId: String) async throws -> EnhancedAssignedServerResponse {
        let response: AssignedServerResponse = try await send(
            Request(
                method: .GET,
                path: "/v1/orgDevices/\(deviceId)/relationships/assignedServer",
                scope: creds.scope,
                body: nil
            )
        )
        
        // If there's no assigned server, return the basic response
        guard let assignedData = response.data else {
            return EnhancedAssignedServerResponse(
                data: nil,
                links: response.links
            )
        }
        
        // Look up the server details to get the name
        let servers = try await listMdmServers()
        let serverDetails = servers.first { $0.id == assignedData.id }
        
        return EnhancedAssignedServerResponse(
            data: EnhancedAssignedServerData(
                type: assignedData.type,
                id: assignedData.id,
                serverName: serverDetails?.serverName,
                serverType: serverDetails?.serverType
            ),
            links: response.links
        )
    }

    func getMdmServerIdByName(_ name: String) async throws -> String {
        let servers = try await listMdmServers()
        guard let server = servers.first(where: { $0.serverName?.lowercased() == name.lowercased() }) else {
            throw RuntimeError("MDM server '\(name)' not found. Available servers: \(servers.compactMap(\.serverName).joined(separator: ", "))")
        }
        return server.id
    }

    func send<T: Decodable>(_ req: Request<T>) async throws -> T {
        if token.isExpired { token = try await Self.fetchToken(creds, session: session) }
        
        let url: URL = req.path.hasPrefix("https://")
            ? URL(string: req.path)!
            : URL(string: req.path, relativeTo: Endpoints.base(for: creds.scope))!
        
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = req.method.rawValue
        urlReq.httpBody = req.body
        urlReq.setValue("Bearer \(token.access_token)", forHTTPHeaderField: "Authorization")
        urlReq.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Set Content-Type for requests with body
        if req.body != nil {
            urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return try await performRequestWithRetry(urlReq)
    }
    
    private func performRequestWithRetry<T: Decodable>(_ urlReq: URLRequest) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                let (data, resp) = try await session.data(for: urlReq)
                guard let http = resp as? HTTPURLResponse else {
                    throw RuntimeError("Invalid response type")
                }
                
                // Handle successful responses
                if http.statusCode == 200 || http.statusCode == 201 {
                    return try JSONDecoder().decode(T.self, from: data)
                }
                
                // Handle 429 (Rate Limited) and other retryable errors
                if shouldRetry(statusCode: http.statusCode, attempt: attempt) {
                    let delay = calculateBackoffDelay(attempt: attempt, response: http)
                    
                    FileHandle.standardError.write(
                        Data("HTTP \(http.statusCode) - Retrying in \(String(format: "%.1f", delay))s (attempt \(attempt + 1)/\(maxRetries + 1))\n".utf8)
                    )
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                // Non-retryable error - print diagnostic and throw
                FileHandle.standardError.write(
                    Data("HTTP \(http.statusCode)\n".utf8)
                )
                FileHandle.standardError.write(data)
                FileHandle.standardError.write(Data("\n".utf8))
                throw RuntimeError("HTTP error \(http.statusCode)")
                
            } catch {
                lastError = error
                
                // Don't retry on decoding errors or other non-network errors
                if !isNetworkError(error) || attempt == maxRetries {
                    throw error
                }
                
                let delay = calculateBackoffDelay(attempt: attempt, response: nil)
                FileHandle.standardError.write(
                    Data("Network error - Retrying in \(String(format: "%.1f", delay))s (attempt \(attempt + 1)/\(maxRetries + 1)): \(error.localizedDescription)\n".utf8)
                )
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? RuntimeError("All retry attempts failed")
    }
    
    private func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        
        switch statusCode {
        case 429: // Rate Limited
            return true
        case 500...599: // Server errors
            return true
        case 408: // Request Timeout
            return true
        default:
            return false
        }
    }
    
    private func calculateBackoffDelay(attempt: Int, response: HTTPURLResponse?) -> Double {
        // Check for Retry-After header in 429 responses
        if let response = response,
           response.statusCode == 429,
           let retryAfterString = response.value(forHTTPHeaderField: "Retry-After"),
           let retryAfter = Double(retryAfterString) {
            return min(retryAfter, maxDelaySeconds)
        }
        
        // Exponential backoff: baseDelay * 2^attempt with jitter
        let exponentialDelay = baseDelaySeconds * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0.8...1.2) // ±20% jitter
        let delay = exponentialDelay * jitter
        
        return min(delay, maxDelaySeconds)
    }
    
    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        return false
    }

    private static func fetchToken(_ c: Credentials,
                                session: URLSession) async throws -> Token {

        let jwt = try makeJWT(c)
        let allowed = CharacterSet.urlQueryAllowed.subtracting(.init(charactersIn: "+&="))
        let params: [(String,String)] = [
            ("grant_type", "client_credentials"),
            ("client_id",  c.clientId),
            ("client_assertion_type",
             "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"),
            ("client_assertion", jwt),
            ("scope", c.scope)
        ]

        let query = params
            .map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: allowed)!)" }
            .joined(separator: "&")

        var components = URLComponents(
            string: "https://account.apple.com/auth/oauth2/token"
        )!
        components.percentEncodedQuery = query

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded",
                     forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await session.data(for: req)
        let http = resp as? HTTPURLResponse
        if http?.statusCode != 200 {
            FileHandle.standardError.write(Data("TOKEN-URL → \(req.url!.absoluteString)\n".utf8))
            FileHandle.standardError.write(data)   // Apple's JSON
            FileHandle.standardError.write(Data("\n".utf8))
            throw RuntimeError("authentication failed – HTTP \(http?.statusCode ?? 0)")
        }
        return try JSONDecoder().decode(Token.self, from: data)
    }

    private static func makeJWT(_ c: Credentials) throws -> String {
        let header = ["alg": "ES256", "kid": c.keyId, "typ": "JWT"]
        let now    = Int(Date().timeIntervalSince1970)
        let claims: [String: Any] = [
            "iss": c.clientId,
            "sub": c.clientId,
            "aud": "https://account.apple.com/auth/oauth2/v2/token",
            "iat": now,
            "exp": now + 1_200,
            "jti": UUID().uuidString
        ]

        func b64url(_ o: Any) throws -> String {
            let d = try JSONSerialization.data(withJSONObject: o)
            return d.base64EncodedString()
                    .replacingOccurrences(of: "=", with: "")
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
        }

        let header64 = try b64url(header)
        let claims64 = try b64url(claims)
        let unsigned = header64 + "." + claims64

        let key = try makeKey(from: c.privateKeyPEM)
        let sig = try key.signature(for: Data(unsigned.utf8))
                        .rawRepresentation               // ← RAW 64-byte form

        let sig64 = Data(sig).base64EncodedString()        // base64-URL encode …
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        return unsigned + "." + sig64
    }
}

import CryptoKit
import Foundation

private func makeKey(from pem: String) throws -> P256.Signing.PrivateKey {
    let clean = pem.trimmingCharacters(in: .whitespacesAndNewlines)
    do {                                        // try PKCS#8 first
        return try P256.Signing.PrivateKey(pemRepresentation: clean)
    } catch {
        guard clean.contains("BEGIN EC PRIVATE KEY") else { throw error }
        // fall back: convert SEC-1 → PKCS#8 via /usr/bin/openssl
        guard let pkcs8 = try convertSEC1toPKCS8(clean) else { throw error }
        return try P256.Signing.PrivateKey(pemRepresentation: pkcs8)
    }
}

private func convertSEC1toPKCS8(_ sec1: String) throws -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
    p.arguments = ["pkcs8", "-topk8", "-nocrypt", "-inform", "PEM", "-outform", "PEM"]
    let inPipe = Pipe();  p.standardInput  = inPipe
    let outPipe = Pipe(); p.standardOutput = outPipe
    try p.run()
    inPipe.fileHandleForWriting.write(Data(sec1.utf8))
    inPipe.fileHandleForWriting.closeFile()
    let pkcs8 = try outPipe.fileHandleForReading.readToEnd().flatMap { String(data: $0, encoding: .utf8) }
    p.waitUntilExit()
    return p.terminationStatus == 0 ? pkcs8 : nil
}

// Add response types at the end of the file
struct AssignedServerResponse: Codable {
    let data: AssignedServerData?
    let links: AssignedServerLinks?
}

struct AssignedServerData: Codable {
    let type: String
    let id: String
}

struct AssignedServerLinks: Codable {
    let `self`: String
    let related: String
}

// Add enhanced response types at the end of the file
struct EnhancedAssignedServerResponse: Codable {
    let data: EnhancedAssignedServerData?
    let links: AssignedServerLinks?
}

struct EnhancedAssignedServerData: Codable {
    let type: String
    let id: String
    let serverName: String?
    let serverType: String?
}

// Add new response structures and enhance the createDeviceActivity method to return detailed information.
struct ActivityDetails: Codable {
    let id: String
    let activityType: String
    let status: String
    let createdDateTime: String
    let updatedDateTime: String
    let deviceCount: Int
    let deviceSerials: [String]
    let mdmServerName: String?
    let mdmServerType: String?
    let mdmServerId: String
}