import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class DeviceLookupViewModel {
    var serialInput = ""
    var importedSerials: [String] = []
    var results: [DeviceMdmResult] = []
    var isLoading = false
    var errorMessage: String?

    var serialNumbers: [String] {
        if !importedSerials.isEmpty {
            return importedSerials
        }
        return serialInput
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var assignedCount: Int {
        results.filter { $0.assignedMdm != nil }.count
    }

    func lookup(client: APIClient) async {
        let serials = serialNumbers
        guard !serials.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        results.removeAll()

        do {
            let serialSet = Set(serials.map { $0.uppercased() })
            let servers = try await client.listMdmServers()

            var assignments: [String: AssignedMdmInfo] = [:]
            for server in servers {
                let deviceSerials = try await client.listMdmServerDevices(serverId: server.id)
                for serial in deviceSerials {
                    let upper = serial.uppercased()
                    if serialSet.contains(upper) {
                        assignments[upper] = AssignedMdmInfo(
                            id: server.id,
                            serverName: server.serverName,
                            serverType: server.serverType
                        )
                    }
                }
            }

            results = serials.map { serial in
                DeviceMdmResult(
                    serialNumber: serial,
                    assignedMdm: assignments[serial.uppercased()]
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access file"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            importedSerials = try CSVParser.readSerials(from: url)
        } catch {
            errorMessage = "CSV import failed: \(error.localizedDescription)"
        }
    }

    func reset() {
        serialInput = ""
        importedSerials.removeAll()
        results.removeAll()
        errorMessage = nil
    }
}
