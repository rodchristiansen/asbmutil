import SwiftUI
import ASBMUtilCore

struct DeviceDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = DeviceInfoViewModel()
    @State private var showJSON = false
    @State private var servers: [MdmServerWithId] = []
    @State private var selectedServerName = ""
    @State private var isAssigning = false
    @State private var assignResult: ActivityDetails?
    @State private var assignError: String?

    let serialNumber: String

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("Retry") { Task { await loadInfo() } }.font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let info = viewModel.deviceInfo {
                deviceContent(info)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { Task { await loadInfo() } }
            }
        }
        .sheet(isPresented: $showJSON) {
            if let info = viewModel.deviceInfo {
                JSONViewerView(title: serialNumber, encodable: info)
            }
        }
        .onChange(of: serialNumber) { _, _ in
            viewModel.deviceInfo = nil
            assignResult = nil
            assignError = nil
            selectedServerName = ""
            Task { await loadInfo() }
        }
        .task {
            if servers.isEmpty {
                do {
                    let client = try await appViewModel.ensureConnected()
                    servers = try await client.listMdmServers()
                } catch {}
            }
        }
    }

    private func loadInfo() async {
        do {
            let client = try await appViewModel.ensureConnected()
            await viewModel.loadDevice(serial: serialNumber, client: client)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Content

    private func deviceContent(_ info: DeviceInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.device.serialNumber)
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                            .textSelection(.enabled)
                        Text(info.device.displayModel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            if let family = info.device.productFamily {
                                Text(family).font(.caption)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.quaternary).clipShape(Capsule())
                            }
                            StatusBadge(status: info.device.status ?? "")
                            if let serverName = info.assignedMdm?.serverName {
                                Text(serverName).font(.caption)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                    Button { showJSON = true } label: {
                        Image(systemName: "curlybraces")
                    }
                    .buttonStyle(.borderless)
                    .help("View JSON")
                }

                Divider()

                // Assign / Unassign actions
                assignSection(currentMdm: info.assignedMdm)

                Divider()

                section("Identity", rows: identityRows(info.device))
                section("Purchase", rows: purchaseRows(info.device))
                section("Network", rows: networkRows(info.device))
                section("Timestamps", rows: timestampRows(info.device))

                if let coverages = info.appleCareCoverage, !coverages.isEmpty {
                    ForEach(Array(coverages.enumerated()), id: \.offset) { i, c in
                        section(i == 0 ? "AppleCare" : "", rows: appleCareRows(c))
                    }
                }

                section("Server Assignment", rows: serverRows(info.assignedMdm))
            }
            .padding(12)
        }
    }

    // MARK: - Assign / Unassign

    @ViewBuilder
    private func assignSection(currentMdm: AssignedMdmInfo?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manage Assignment")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary).textCase(.uppercase)

            if assignResult != nil {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.callout)
                if let r = assignResult {
                    Text("Activity: \(r.id)")
                        .font(.caption2).fontDesign(.monospaced)
                        .foregroundStyle(.tertiary).textSelection(.enabled)
                }
            } else {
                if currentMdm != nil {
                    // Can reassign or unassign
                    Picker("Server", selection: $selectedServerName) {
                        Text("Select a server...").tag("")
                        ForEach(servers, id: \.id) { s in
                            Text(s.serverName ?? s.id).tag(s.serverName ?? "")
                        }
                    }
                    .controlSize(.small)

                    HStack(spacing: 8) {
                        Button("Reassign") {
                            Task { await performAssign(type: "ASSIGN_DEVICES") }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(selectedServerName.isEmpty || isAssigning)

                        Button("Unassign") {
                            Task { await performUnassign(currentMdm: currentMdm!) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.small)
                        .disabled(isAssigning)

                        if isAssigning { ProgressView().controlSize(.small) }
                    }
                } else {
                    // Not assigned - can assign
                    Picker("Server", selection: $selectedServerName) {
                        Text("Select a server...").tag("")
                        ForEach(servers, id: \.id) { s in
                            Text(s.serverName ?? s.id).tag(s.serverName ?? "")
                        }
                    }
                    .controlSize(.small)

                    HStack {
                        Button("Assign") {
                            Task { await performAssign(type: "ASSIGN_DEVICES") }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(selectedServerName.isEmpty || isAssigning)

                        if isAssigning { ProgressView().controlSize(.small) }
                    }
                }

                if let assignError {
                    Text(assignError)
                        .foregroundStyle(.red).font(.caption2)
                }
            }
        }
    }

    private func performAssign(type: String) async {
        isAssigning = true; assignError = nil
        do {
            let client = try await appViewModel.ensureConnected()
            let serviceId = try await client.getMdmServerIdByName(selectedServerName)
            assignResult = try await client.createDeviceActivity(
                activityType: type, serials: [serialNumber], serviceId: serviceId
            )
        } catch {
            assignError = error.localizedDescription
        }
        isAssigning = false
    }

    private func performUnassign(currentMdm: AssignedMdmInfo) async {
        isAssigning = true; assignError = nil
        do {
            let client = try await appViewModel.ensureConnected()
            assignResult = try await client.createDeviceActivity(
                activityType: "UNASSIGN_DEVICES", serials: [serialNumber], serviceId: currentMdm.id
            )
        } catch {
            assignError = error.localizedDescription
        }
        isAssigning = false
    }

    // MARK: - Section renderer

    private func section(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary).textCase(.uppercase)
                    .padding(.bottom, 2)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    Text(row.0)
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .trailing)
                    Text(row.1)
                        .font(.callout).textSelection(.enabled)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Row builders

    private func identityRows(_ d: DeviceAttributes) -> [(String, String)] {
        [("Model", d.displayModel), ("Family", d.productFamily ?? "-"),
         ("Type", d.productType ?? "-"), ("Color", d.color ?? "-"),
         ("Storage", d.deviceCapacity ?? "-")]
    }

    private func networkRows(_ d: DeviceAttributes) -> [(String, String)] {
        var r: [(String, String)] = []
        if let v = d.wifiMacAddress { r.append(("Wi-Fi MAC", v.allValues.joined(separator: ", "))) }
        if let v = d.bluetoothMacAddress { r.append(("Bluetooth", v.allValues.joined(separator: ", "))) }
        if let v = d.builtInEthernetMacAddress { r.append(("Ethernet", v.allValues.joined(separator: ", "))) }
        if let v = d.imei { r.append(("IMEI", v.allValues.joined(separator: ", "))) }
        if let v = d.meid { r.append(("MEID", v.allValues.joined(separator: ", "))) }
        if let v = d.eid { r.append(("EID", v.allValues.joined(separator: ", "))) }
        return r.isEmpty ? [("", "No network identifiers")] : r
    }

    private func purchaseRows(_ d: DeviceAttributes) -> [(String, String)] {
        [("Order #", d.orderNumber ?? "-"), ("Order Date", d.orderDateTime ?? "-"),
         ("Part #", d.partNumber ?? "-"), ("Source", d.purchaseSourceType ?? "-"),
         ("Source ID", d.purchaseSourceId ?? "-")]
    }

    private func timestampRows(_ d: DeviceAttributes) -> [(String, String)] {
        [("Added", d.addedToOrgDateTime ?? "-"), ("Updated", d.updatedDateTime ?? "-")]
    }

    private func appleCareRows(_ c: AppleCareAttributes) -> [(String, String)] {
        [("Plan", c.description ?? "-"), ("Status", c.status ?? "-"),
         ("Start", c.startDateTime ?? "-"), ("End", c.endDateTime ?? "-"),
         ("Renewable", c.isRenewable == true ? "Yes" : "No")]
    }

    private func serverRows(_ mdm: AssignedMdmInfo?) -> [(String, String)] {
        guard let mdm else { return [("", "Not assigned")] }
        return [("Server", mdm.serverName ?? "-"), ("Type", mdm.serverType ?? "-"), ("ID", mdm.id)]
    }
}
