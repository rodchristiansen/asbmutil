import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class MDMServersViewModel {
    var servers: [MdmServerWithId] = []
    var isLoading = false
    var errorMessage: String?

    // Server detail
    var selectedServerDevices: [String] = []
    var isLoadingDevices = false
    var deviceLoadError: String?

    func loadServers(client: APIClient) async {
        isLoading = true
        errorMessage = nil

        do {
            servers = try await client.listMdmServers()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadDevicesForServer(serverId: String, client: APIClient) async {
        isLoadingDevices = true
        deviceLoadError = nil
        selectedServerDevices.removeAll()

        do {
            selectedServerDevices = try await client.listMdmServerDevices(serverId: serverId)
        } catch {
            deviceLoadError = error.localizedDescription
        }

        isLoadingDevices = false
    }
}
