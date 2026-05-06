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

    // Shared device + server caches (Dashboard and Devices both read from these)
    var devices: [DeviceAttributes] = []
    var mdmServers: [MdmServerWithId] = []
    var serverDeviceCounts: [String: Int] = [:]
    var isLoadingDevices = false
    var isLoadingServerCounts = false
    var deviceLoadError: String?
    var devicesLastLoaded: Date?

    // Shared device filter state — survives navigation between sections
    let deviceFilters = DeviceFilters()

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
        devices = []
        mdmServers = []
        serverDeviceCounts = [:]
        deviceLoadError = nil
        devicesLastLoaded = nil
        deviceFilters.clearAll()
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

    // MARK: - Device + Server loading

    func loadDevices(force: Bool = false) async {
        if !force, !devices.isEmpty { return }
        isLoadingDevices = true
        deviceLoadError = nil
        do {
            let client = try await ensureConnected()
            async let deviceList = client.listDevices(devicesPerPage: 1000, totalLimit: nil, showPagination: false)
            async let serverList = client.listMdmServers()
            let (loaded, servers) = try await (deviceList, serverList)
            devices = loaded
            mdmServers = servers
            devicesLastLoaded = Date()
            deviceFilters.buildFromDevices(loaded)
        } catch {
            deviceLoadError = error.localizedDescription
        }
        isLoadingDevices = false

        // Kick off per-server counts in the background — dashboard server card
        // needs them but the rest of the dashboard can render without them.
        Task { await self.loadServerDeviceCounts() }
    }

    func refreshDevices() async {
        serverDeviceCounts = [:]
        await loadDevices(force: true)
    }

    /// listDevices doesn't return assignedServer relationships, so the dashboard's
    /// per-server counts come from listMdmServerDevices fanned out per server.
    func loadServerDeviceCounts() async {
        guard let client = apiClient, !mdmServers.isEmpty else { return }
        isLoadingServerCounts = true
        let servers = mdmServers
        let counts = await withTaskGroup(of: (String, Int)?.self) { group -> [String: Int] in
            for server in servers {
                let id = server.id
                group.addTask {
                    do {
                        let serials = try await client.listMdmServerDevices(serverId: id)
                        return (id, serials.count)
                    } catch {
                        return nil
                    }
                }
            }
            var out: [String: Int] = [:]
            for await result in group {
                if let (id, count) = result { out[id] = count }
            }
            return out
        }
        serverDeviceCounts = counts
        isLoadingServerCounts = false
    }
}
