import Foundation
import SwiftUI
import ASBMUtilCore

/// The operations the app can submit to `POST /v1/orgDeviceActivities`.
enum AssignmentMode: String, CaseIterable, Identifiable {
    case assign = "Assign"
    case unassign = "Unassign"
    /// Assign with a migration deadline (API 1.6 School / 2.3 Business).
    case migrate = "Migrate"
    case updateDeadline = "Update Deadline"
    case cancelMigration = "Cancel Migration"
    /// Release from the organization (API 2.4, Business only; irreversible).
    case release = "Release"

    var id: String { rawValue }

    var activityType: DeviceActivityType {
        switch self {
        case .assign: .assignDevices
        case .unassign: .unassignDevices
        case .migrate: .assignDevicesWithMdmMigrationDeadline
        case .updateDeadline: .updateMdmMigrationDeadline
        case .cancelMigration: .cancelMdmMigration
        case .release: .releaseDevices
        }
    }

    var needsServer: Bool { activityType.requiresMdmServer }
    var needsDeadline: Bool { activityType.requiresMigrationDeadline }
    var isDestructive: Bool { self == .release }

    var buttonTitle: String {
        switch self {
        case .assign: "Assign Devices"
        case .unassign: "Unassign Devices"
        case .migrate: "Schedule Migration"
        case .updateDeadline: "Update Deadline"
        case .cancelMigration: "Cancel Migration"
        case .release: "Release Devices"
        }
    }

    var tint: Color {
        switch self {
        case .assign, .migrate: .blue
        case .unassign, .updateDeadline: .orange
        case .cancelMigration: .gray
        case .release: .red
        }
    }

    var systemImage: String {
        switch self {
        case .assign: "arrow.right.square"
        case .unassign: "arrow.uturn.backward.square"
        case .migrate: "calendar.badge.clock"
        case .updateDeadline: "calendar.badge.exclamationmark"
        case .cancelMigration: "calendar.badge.minus"
        case .release: "trash.square"
        }
    }

    var help: String {
        switch self {
        case .assign: "Assign the devices to the selected device management service."
        case .unassign: "Unassign the devices from the selected device management service."
        case .migrate: "Assign the devices to the selected service and schedule a no-erase migration that must complete by the deadline. Users are prompted and can defer until then."
        case .updateDeadline: "Move the deadline of an in-progress migration. An earlier or past deadline is enforced on the device immediately."
        case .cancelMigration: "Cancel an in-progress migration. Devices with no migration pending are reported as failures in Apple's activity log."
        case .release: "Remove the devices from the organization permanently. Enrollment assignments are removed, devices are unenrolled from the built-in service and dropped from Blueprints."
        }
    }

    /// Modes the current tenant can use. Release exists only on the Apple Business API.
    static func available(business: Bool) -> [AssignmentMode] {
        allCases.filter { business || !$0.isDestructive }
    }

    /// Mode that best matches an existing activity type string, for history rows.
    static func from(activityType: String) -> AssignmentMode? {
        allCases.first { $0.activityType.rawValue == activityType }
    }
}

/// Deadline helpers shared by every view that submits a migration.
enum MigrationDeadline {
    static var defaultDate: Date { Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date() }
    static var maxDate: Date { Calendar.current.date(byAdding: .day, value: mdmMigrationDeadlineMaxDays, to: Date()) ?? Date() }

    /// ISO 8601 UTC without fractional seconds, the form Apple's examples use.
    static func isoString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    /// Nil when acceptable, otherwise the reason Apple would reject it.
    static func problem(with date: Date, allowPast: Bool) -> String? {
        let now = Date()
        if date <= now && !allowPast {
            return "Deadline is in the past."
        }
        if date.timeIntervalSince(now) > TimeInterval(mdmMigrationDeadlineMaxDays * 24 * 60 * 60) {
            return "Deadline is more than \(mdmMigrationDeadlineMaxDays) days out; Apple rejects deadlines beyond \(mdmMigrationDeadlineMaxDays) days."
        }
        return nil
    }
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

    /// Migration deadline for `.migrate` and `.updateDeadline`.
    var deadline: Date = MigrationDeadline.defaultDate
    /// Permit a past deadline on `.updateDeadline`, which forces the migration immediately.
    var allowPastDeadline = false
    /// The user has acknowledged that `.release` is irreversible.
    var acknowledgeRelease = false

    /// Skip the pre-flight existence check and submit serials as-is.
    var skipVerify = false
    /// Serials Apple reported as not found (HTTP 404) during the last run — excluded from submission.
    var notFoundSerials: [String] = []
    /// Serials whose existence couldn't be determined during the last run — excluded from submission.
    var erroredSerials: [String] = []

    /// After submitting, poll the activity and re-query each device to confirm the end state.
    var confirmAfterSubmit = false
    /// Whether a confirmation pass ran and produced results to show.
    var didConfirm = false
    /// Human-readable terminal status of the confirmed activity (e.g. COMPLETED, TIMEOUT).
    var confirmStatus: String?
    /// Count of devices confirmed in the expected end state.
    var confirmedCount = 0
    /// Serials that settled in a different state than intended.
    var confirmMismatched: [String] = []
    /// Serials whose final state couldn't be read.
    var confirmErrored: [String] = []

    var serialNumbers: [String] {
        if !importedSerials.isEmpty {
            return importedSerials
        }
        return serialInput
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var deadlineProblem: String? {
        guard mode.needsDeadline else { return nil }
        return MigrationDeadline.problem(with: deadline, allowPast: mode == .updateDeadline && allowPastDeadline)
    }

    var canExecute: Bool {
        guard !serialNumbers.isEmpty, !isExecuting else { return false }
        if mode.needsServer && selectedMdmName.isEmpty { return false }
        if deadlineProblem != nil { return false }
        if mode.isDestructive && !acknowledgeRelease { return false }
        return true
    }

    func loadServers(client: APIClient) async {
        do {
            servers = try await client.listMdmServers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Submit one activity for `mode`. Shared with the inline and detail views so every entry
    /// point builds the same request.
    static func submit(
        mode: AssignmentMode,
        serials: [String],
        serviceId: String?,
        deadline: Date?,
        client: APIClient
    ) async throws -> ActivityDetails {
        try await client.createDeviceActivity(
            type: mode.activityType,
            serials: serials,
            serviceId: mode.needsServer ? serviceId : nil,
            mdmMigrationDeadlineDateTime: mode.needsDeadline ? deadline.map(MigrationDeadline.isoString) : nil
        )
    }

    func execute(client: APIClient) async {
        guard canExecute else { return }
        isExecuting = true
        errorMessage = nil
        result = nil
        notFoundSerials = []
        erroredSerials = []
        didConfirm = false
        confirmStatus = nil
        confirmedCount = 0
        confirmMismatched = []
        confirmErrored = []

        do {
            let serviceId: String? = mode.needsServer
                ? try await client.getMdmServerIdByName(selectedMdmName)
                : nil

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

            let activity = try await Self.submit(
                mode: mode,
                serials: toSubmit,
                serviceId: serviceId,
                deadline: deadline,
                client: client
            )
            result = activity

            // Optionally poll to completion and reconcile each device's actual end state.
            if confirmAfterSubmit {
                let status = try await client.waitForActivityTerminal(
                    id: activity.id,
                    intervalSeconds: 10,
                    timeoutSeconds: 240
                )
                confirmStatus = status
                if status != "TIMEOUT" {
                    await reconcile(serials: toSubmit, serviceId: serviceId, client: client)
                }
                didConfirm = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isExecuting = false
    }

    private func reconcile(serials: [String], serviceId: String?, client: APIClient) async {
        switch mode {
        case .assign, .unassign:
            guard let serviceId else { return }
            let expected: AssignmentExpectation = mode == .assign
                ? .assigned(serverId: serviceId)
                : .unassigned(serverId: serviceId)
            let r = await client.confirmAssignment(serials: serials, expected: expected)
            confirmedCount = r.asExpected.count
            confirmMismatched = r.mismatched.map { "\($0.serial): now \($0.assignedTo.map { "on \($0)" } ?? "unassigned")" }
            confirmErrored = r.errored.map { "\($0.serial): \($0.message)" }

        case .migrate, .updateDeadline, .cancelMigration:
            let expected: MigrationExpectation = mode == .cancelMigration
                ? .cancelled
                : .scheduled(deadline: MigrationDeadline.isoString(deadline))
            let r = await client.confirmMdmMigration(serials: serials, expected: expected)
            confirmedCount = r.asExpected.count
            confirmMismatched = r.mismatched.map { m in
                let state = m.mdmMigrationStatus ?? "no migration"
                let deadline = m.mdmMigrationDeadlineDateTime.map { " deadline \($0)" } ?? ""
                let capable = m.isMdmMigrationCapable == false ? " (not migration-capable)" : ""
                return "\(m.serialNumber): \(state)\(deadline)\(capable)"
            }
            confirmErrored = r.errored.map { "\($0.serial): \($0.message)" }

        case .release:
            let r = await client.confirmRelease(serials: serials)
            confirmedCount = r.released.count
            confirmMismatched = r.stillPresent.map { "\($0): still in the organization" }
            confirmErrored = r.errored.map { "\($0.serial): \($0.message)" }
        }
    }

    func reset() {
        serialInput = ""
        importedSerials.removeAll()
        result = nil
        errorMessage = nil
        notFoundSerials = []
        erroredSerials = []
        didConfirm = false
        confirmStatus = nil
        confirmedCount = 0
        confirmMismatched = []
        confirmErrored = []
        acknowledgeRelease = false
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
