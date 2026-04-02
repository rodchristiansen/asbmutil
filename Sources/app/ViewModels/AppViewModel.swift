import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class AppViewModel {
    // Profile management
    private(set) var profiles: [ProfileInfo] = []
    var activeProfile: String = "default"
    private(set) var isAuthenticated = false

    // Shared API client (recreated on profile switch)
    private(set) var apiClient: APIClient?

    // Connection status
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var connectionError: String?

    // XPC client
    let xpcClient = XPCClient()

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    init() {
        loadProfiles()
    }

    func loadProfiles() {
        profiles = Keychain.listProfiles()
        activeProfile = Keychain.getCurrentProfile()
    }

    func switchProfile(_ name: String) async {
        activeProfile = name
        _ = Keychain.setCurrentProfile(name)
        apiClient = nil
        connectionState = .disconnected
        isAuthenticated = false
        connectionError = nil
    }

    func connect() async {
        connectionState = .connecting
        connectionError = nil

        do {
            let credentials = try Creds.load(profileName: activeProfile)
            let client = try await APIClient(credentials: credentials, profileName: activeProfile)
            apiClient = client
            connectionState = .connected
            isAuthenticated = true
        } catch {
            connectionState = .error(error.localizedDescription)
            connectionError = error.localizedDescription
            isAuthenticated = false
            apiClient = nil
        }
    }

    func disconnect() {
        apiClient = nil
        connectionState = .disconnected
        isAuthenticated = false
        connectionError = nil
    }

    /// Ensure we have an active API client, connecting if needed
    func ensureConnected() async throws -> APIClient {
        if let client = apiClient {
            return client
        }
        await connect()
        guard let client = apiClient else {
            throw RuntimeError(connectionError ?? "Failed to connect")
        }
        return client
    }
}
