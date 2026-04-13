import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class DeviceInfoViewModel {
    var deviceInfo: DeviceInfo?
    var isLoading = false
    var errorMessage: String?

    func loadDevice(serial: String, client: APIClient) async {
        isLoading = true
        errorMessage = nil

        do {
            deviceInfo = try await client.getDevice(serialNumber: serial)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
