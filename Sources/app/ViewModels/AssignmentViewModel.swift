import Foundation
import ASBMUtilCore

enum AssignmentMode: String, CaseIterable {
    case assign = "Assign"
    case unassign = "Unassign"
}

@Observable
@MainActor
final class AssignmentViewModel {
    var mode: AssignmentMode = .assign
    var selectedMdmName = ""
    var serialInput = ""
    var importedSerials: [String] = []
    var isExecuting = false
    var result: ActivityDetails?
    var errorMessage: String?
    var servers: [MdmServerWithId] = []

    var serialNumbers: [String] {
        if !importedSerials.isEmpty {
            return importedSerials
        }
        return serialInput
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var canExecute: Bool {
        !selectedMdmName.isEmpty && !serialNumbers.isEmpty && !isExecuting
    }

    func loadServers(client: APIClient) async {
        do {
            servers = try await client.listMdmServers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func execute(client: APIClient) async {
        guard canExecute else { return }
        isExecuting = true
        errorMessage = nil
        result = nil

        do {
            let serviceId = try await client.getMdmServerIdByName(selectedMdmName)
            let activityType = mode == .assign ? "ASSIGN_DEVICES" : "UNASSIGN_DEVICES"
            result = try await client.createDeviceActivity(
                activityType: activityType,
                serials: serialNumbers,
                serviceId: serviceId
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isExecuting = false
    }

    func reset() {
        serialInput = ""
        importedSerials.removeAll()
        result = nil
        errorMessage = nil
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
}
