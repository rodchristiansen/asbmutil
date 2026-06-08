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

    /// Skip the pre-flight existence check and submit serials as-is.
    var skipVerify = false
    /// Serials Apple reported as not found (HTTP 404) during the last run — excluded from submission.
    var notFoundSerials: [String] = []
    /// Serials whose existence couldn't be determined during the last run — excluded from submission.
    var erroredSerials: [String] = []

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
        notFoundSerials = []
        erroredSerials = []

        do {
            let serviceId = try await client.getMdmServerIdByName(selectedMdmName)
            let activityType = mode == .assign ? "ASSIGN_DEVICES" : "UNASSIGN_DEVICES"

            // Pre-flight each serial unless the user opted out. Apple's activities endpoint
            // reports success even for serials that don't exist (e.g. not yet registered by
            // the reseller), so we filter those out and surface them for review.
            let toSubmit: [String]
            if skipVerify {
                toSubmit = serialNumbers
            } else {
                let verification = await client.verifyDevices(serials: serialNumbers)
                notFoundSerials = verification.notFound
                erroredSerials = verification.errored.map { "\($0.serial): \($0.message)" }
                guard !verification.found.isEmpty else {
                    errorMessage = "No valid devices: all \(serialNumbers.count) serial(s) were not found or could not be verified."
                    isExecuting = false
                    return
                }
                toSubmit = verification.found
            }

            result = try await client.createDeviceActivity(
                activityType: activityType,
                serials: toSubmit,
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
        notFoundSerials = []
        erroredSerials = []
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
