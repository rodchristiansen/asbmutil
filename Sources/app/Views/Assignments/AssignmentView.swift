import SwiftUI
import UniformTypeIdentifiers
import ASBMUtilCore

struct AssignmentView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = AssignmentViewModel()
    @State private var showFilePicker = false
    @State private var activityHistory: [ActivityDetails] = []

    var body: some View {
        VSplitView {
            actionsSection
            historySection
        }
        .navigationTitle("Assignments")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importCSV(from: url)
            }
        }
        .task {
            if viewModel.servers.isEmpty { await loadServers() }
        }
    }

    // MARK: - Actions section

    private var actionsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Operation") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Mode", selection: $viewModel.mode) {
                            ForEach(AssignmentMode.available(business: appViewModel.isBusinessTenant)) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(viewModel.mode.help)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 16) {
                    if viewModel.mode.needsServer {
                        GroupBox("Server") {
                            serverPicker
                        }
                    }
                    if viewModel.mode.needsDeadline {
                        GroupBox("Migration Deadline") {
                            deadlinePicker
                        }
                    }
                }

                if viewModel.mode.isDestructive {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Releasing is permanent", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red).font(.callout.weight(.semibold))
                            Text("Released devices leave the organization. Enrollment assignments are removed, they are unenrolled from the built-in device management service and dropped from Blueprints. There is no undo.")
                                .font(.caption).foregroundStyle(.secondary)
                            Toggle("I understand these devices will be released permanently", isOn: $viewModel.acknowledgeRelease)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("Device Serials") {
                    serialInputSection
                }

                executeSection
            }
            .padding()
        }
        .frame(minHeight: 220)
    }

    @ViewBuilder
    private var serverPicker: some View {
        if viewModel.servers.isEmpty {
            HStack {
                Text("No servers loaded").foregroundStyle(.secondary)
                Spacer()
                Button("Load") { Task { await loadServers() } }
            }
        } else {
            Picker("Server", selection: $viewModel.selectedMdmName) {
                Text("Select a server...").tag("")
                ForEach(viewModel.servers, id: \.id) { s in
                    Text(s.serverName ?? s.id).tag(s.serverName ?? "")
                }
            }
        }
    }

    private var deadlinePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(
                "Deadline",
                selection: $viewModel.deadline,
                in: (viewModel.mode == .updateDeadline && viewModel.allowPastDeadline ? Date.distantPast : Date())...MigrationDeadline.maxDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            Text("Sent as \(MigrationDeadline.isoString(viewModel.deadline)). At most \(mdmMigrationDeadlineMaxDays) days out.")
                .font(.caption2).foregroundStyle(.tertiary)
            if viewModel.mode == .updateDeadline {
                Toggle("Allow a past deadline (forces the migration now)", isOn: $viewModel.allowPastDeadline)
                    .font(.caption)
            }
            if let problem = viewModel.deadlineProblem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.caption)
            }
        }
    }

    private var serialInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $viewModel.serialInput)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 50, maxHeight: 70)
                .border(Color.secondary.opacity(0.3))
                .disabled(!viewModel.importedSerials.isEmpty)

            HStack {
                Button("Import CSV") { showFilePicker = true }
                if !viewModel.importedSerials.isEmpty {
                    Text("\(viewModel.importedSerials.count) serials imported")
                        .foregroundStyle(.secondary).font(.caption)
                    Button("Clear") { viewModel.importedSerials.removeAll() }
                        .buttonStyle(.borderless).font(.caption)
                }
                Spacer()
                Text("\(viewModel.serialNumbers.count) serial(s)")
                    .foregroundStyle(.secondary).font(.caption)
            }

            Toggle("Verify serials exist before submitting", isOn: Binding(
                get: { !viewModel.skipVerify },
                set: { viewModel.skipVerify = !$0 }
            ))
            .font(.caption)
            .help("Checks each serial against School/Business Manager first. Serials that don't exist (e.g. not yet registered by the reseller) are reported and excluded rather than silently no-op'd.")

            Toggle("Confirm end state after submitting", isOn: $viewModel.confirmAfterSubmit)
                .font(.caption)
                .help("After submitting, waits for the activity to finish and re-queries each device to confirm it actually reached the intended state: the target MDM, a pending migration with this deadline, no pending migration, or released. Slower, since it polls until the activity completes.")
        }
    }

    @ViewBuilder
    private var executeSection: some View {
        HStack {
            Button(viewModel.mode.buttonTitle) {
                Task { await execute() }
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.mode.tint)
            .disabled(!viewModel.canExecute)

            if viewModel.isExecuting { ProgressView().controlSize(.small) }
        }

        if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red).font(.caption)
        }

        if !viewModel.notFoundSerials.isEmpty || !viewModel.erroredSerials.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    if !viewModel.notFoundSerials.isEmpty {
                        Label("\(viewModel.notFoundSerials.count) serial(s) not found — excluded", systemImage: "questionmark.circle")
                            .foregroundStyle(.orange).font(.caption.weight(.medium))
                        Text(viewModel.notFoundSerials.joined(separator: ", "))
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Not in School/Business Manager yet (not registered by the reseller), or mistyped.")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    if !viewModel.erroredSerials.isEmpty {
                        Label("\(viewModel.erroredSerials.count) serial(s) could not be verified — excluded", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).font(.caption.weight(.medium))
                        Text(viewModel.erroredSerials.joined(separator: "\n"))
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let result = viewModel.result {
            GroupBox("Result") {
                HStack {
                    LabeledContent("Activity ID", value: result.id)
                    Spacer()
                    Button("Copy ID") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.id, forType: .string)
                    }.buttonStyle(.borderless).font(.caption)
                }
                LabeledContent("Status", value: result.status)
                LabeledContent("Devices", value: "\(result.deviceCount)")
                if let server = result.mdmServerName ?? result.mdmServerId {
                    LabeledContent("Server", value: server)
                }
                if let deadline = result.mdmMigrationDeadlineDateTime {
                    LabeledContent("Deadline", value: deadline)
                }
            }
        }

        if viewModel.didConfirm {
            GroupBox("Confirmation") {
                VStack(alignment: .leading, spacing: 6) {
                    if let status = viewModel.confirmStatus {
                        LabeledContent("Activity", value: status)
                    }
                    if viewModel.confirmStatus == "TIMEOUT" {
                        Label("Activity didn't finish in time — couldn't confirm end state.", systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange).font(.caption)
                    } else {
                        let total = viewModel.confirmedCount + viewModel.confirmMismatched.count + viewModel.confirmErrored.count
                        Label("\(viewModel.confirmedCount)/\(total) device(s) confirmed in the expected state",
                              systemImage: viewModel.confirmMismatched.isEmpty && viewModel.confirmErrored.isEmpty ? "checkmark.circle" : "exclamationmark.circle")
                            .foregroundStyle(viewModel.confirmMismatched.isEmpty && viewModel.confirmErrored.isEmpty ? .green : .orange)
                            .font(.caption.weight(.medium))
                        if !viewModel.confirmMismatched.isEmpty {
                            Text("Not in expected state:").font(.caption2).foregroundStyle(.secondary)
                            Text(viewModel.confirmMismatched.joined(separator: "\n"))
                                .font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        if !viewModel.confirmErrored.isEmpty {
                            Text("Could not confirm:").font(.caption2).foregroundStyle(.secondary)
                            Text(viewModel.confirmErrored.joined(separator: "\n"))
                                .font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Session Activity")
                    .font(.headline)
                Spacer()
                if !activityHistory.isEmpty {
                    Text("\(activityHistory.count) activities")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal).padding(.vertical, 8)

            Divider()

            if activityHistory.isEmpty {
                Text("Activities from this session will appear here.")
                    .foregroundStyle(.tertiary).font(.caption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(activityHistory) { activity in
                    HStack(spacing: 10) {
                        Image(systemName: AssignmentMode.from(activityType: activity.activityType)?.systemImage ?? "arrow.right.square")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.deviceSerials.count == 1
                                 ? activity.deviceSerials[0] : "Multiple")
                                .font(.callout).fontWeight(.medium)
                            Text(historySubtitle(activity))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: activity.status)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func historySubtitle(_ activity: ActivityDetails) -> String {
        let count = "\(activity.deviceCount) Device\(activity.deviceCount == 1 ? "" : "s")"
        let what = AssignmentMode.from(activityType: activity.activityType)?.rawValue ?? activity.activityType
        var parts = [count, what]
        if let server = activity.mdmServerName ?? activity.mdmServerId { parts.append(server) }
        if let deadline = activity.mdmMigrationDeadlineDateTime { parts.append("by \(deadline)") }
        return parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Actions

    private func loadServers() async {
        do {
            let client = try await appViewModel.ensureConnected()
            await viewModel.loadServers(client: client)
        } catch { viewModel.errorMessage = error.localizedDescription }
    }

    private func execute() async {
        do {
            let client = try await appViewModel.ensureConnected()
            await viewModel.execute(client: client)
            if let result = viewModel.result {
                activityHistory.insert(result, at: 0)
            }
        } catch { viewModel.errorMessage = error.localizedDescription }
    }
}
