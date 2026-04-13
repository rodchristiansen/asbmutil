import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class DeviceListViewModel {
    var devices: [DeviceAttributes] = []
    var isLoading = false
    var hasMore = false
    var devicesPerPage: Int = 1000
    var totalLimit: Int? = nil
    var searchText = ""
    var errorMessage: String?
    private(set) var totalFetched = 0

    var filteredDevices: [DeviceAttributes] {
        guard !searchText.isEmpty else { return devices }
        return devices.filter { device in
            device.serialNumber.localizedCaseInsensitiveContains(searchText) ||
            device.displayModel.localizedCaseInsensitiveContains(searchText) ||
            (device.productFamily ?? "").localizedCaseInsensitiveContains(searchText) ||
            (device.status ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadDevices(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        devices.removeAll()
        totalFetched = 0

        do {
            let result = try await client.listDevices(
                devicesPerPage: devicesPerPage,
                totalLimit: totalLimit,
                showPagination: false
            )
            devices = result
            totalFetched = result.count
            hasMore = false // listDevices fetches all pages
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh(client: APIClient) async {
        await loadDevices(client: client)
    }
}
