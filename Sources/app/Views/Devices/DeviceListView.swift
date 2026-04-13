import SwiftUI
import ASBMUtilCore

// MARK: - Filter Model

enum FilterCategory: String, CaseIterable, Identifiable {
    case status = "Status"
    case source = "Source"
    case orderNumber = "Order Number"
    case productFamily = "Device Type"
    case capacity = "Storage Size"
    var id: String { rawValue }
}

@Observable
@MainActor
final class DeviceFilters {
    var selectedCategory: FilterCategory = .status
    var selectedValues: [FilterCategory: Set<String>] = [:]
    var availableValues: [FilterCategory: [String]] = [:]

    func buildFromDevices(_ devices: [DeviceAttributes]) {
        availableValues[.status] = uniqueSorted(devices.compactMap(\.status))
        availableValues[.source] = uniqueSorted(devices.compactMap(\.purchaseSourceType))
        availableValues[.orderNumber] = uniqueSorted(devices.compactMap(\.orderNumber))
        availableValues[.productFamily] = uniqueSorted(devices.compactMap(\.productFamily))
        availableValues[.capacity] = uniqueSorted(devices.compactMap(\.deviceCapacity))
    }

    func isActive(_ cat: FilterCategory) -> Bool { !(selectedValues[cat]?.isEmpty ?? true) }
    var hasActiveFilters: Bool { selectedValues.values.contains { !$0.isEmpty } }

    func toggle(value: String, in cat: FilterCategory) {
        var s = selectedValues[cat] ?? []
        if s.contains(value) { s.remove(value) } else { s.insert(value) }
        selectedValues[cat] = s
    }
    func clearAll() { selectedValues.removeAll() }

    func matches(_ d: DeviceAttributes) -> Bool {
        for (cat, vals) in selectedValues where !vals.isEmpty {
            let v: String?
            switch cat {
            case .status: v = d.status
            case .source: v = d.purchaseSourceType
            case .orderNumber: v = d.orderNumber
            case .productFamily: v = d.productFamily
            case .capacity: v = d.deviceCapacity
            }
            guard let v, vals.contains(v) else { return false }
        }
        return true
    }

    private func uniqueSorted(_ v: [String]) -> [String] {
        Array(Set(v)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

// MARK: - DeviceListView

struct DeviceListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = DeviceListViewModel()
    @State private var selectedDeviceIDs: Set<String> = []
    @State private var showingInspector = false
    @State private var showFilters = false
    @State private var filters = DeviceFilters()

    private var displayedDevices: [DeviceAttributes] {
        var result = viewModel.filteredDevices
        if filters.hasActiveFilters { result = result.filter { filters.matches($0) } }
        return result
    }

    private var inspectedSerial: String? {
        selectedDeviceIDs.count == 1 ? selectedDeviceIDs.first : nil
    }

    var body: some View {
        mainContent
            .navigationTitle(navigationTitle)
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .toolbar { leadingToolbar }
            .toolbar { trailingToolbar }
            .inspector(isPresented: $showingInspector) { inspectorContent }
            .onChange(of: selectedDeviceIDs) { _, newValue in
                showingInspector = !newValue.isEmpty
            }
            .onChange(of: viewModel.devices) { _, devices in
                filters.buildFromDevices(devices)
            }
            .task {
                if viewModel.devices.isEmpty && !viewModel.isLoading {
                    await loadDevices()
                }
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading devices...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: { Text(error) } actions: {
                Button("Retry") { Task { await loadDevices() } }
            }
        } else if viewModel.devices.isEmpty {
            ContentUnavailableView("No Devices", systemImage: "desktopcomputer")
        } else {
            DeviceTable(devices: displayedDevices, selection: $selectedDeviceIDs)
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorContent: some View {
        Group {
            if let serial = inspectedSerial {
                DeviceDetailView(serialNumber: serial)
                    .environment(appViewModel)
            } else if selectedDeviceIDs.count > 1 {
                InlineAssignView(serials: Array(selectedDeviceIDs))
                    .environment(appViewModel)
            }
        }
        .inspectorColumnWidth(min: 380, ideal: 500, max: 600)
    }

    // MARK: - Toolbars

    @ToolbarContentBuilder
    private var leadingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { showFilters.toggle() } label: {
                Label("Filters", systemImage: filters.hasActiveFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .popover(isPresented: $showFilters) {
                FilterPanelView(filters: filters)
                    .frame(width: 460, height: 340)
            }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItemGroup {
            if filters.hasActiveFilters {
                Button { filters.clearAll() } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }

            Menu {
                ForEach(ExportFormat.allCases) { fmt in
                    Button {
                        ExportService.export(devices: devicesForExport, format: fmt)
                    } label: {
                        Label(fmt.rawValue, systemImage: fmt.icon)
                    }
                }
                Divider()
                Menu("Copy to Clipboard") {
                    ForEach(ExportFormat.allCases) { fmt in
                        Button {
                            ExportService.copyToClipboard(devices: devicesForExport, format: fmt)
                        } label: {
                            Label(fmt.rawValue, systemImage: fmt.icon)
                        }
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(displayedDevices.isEmpty)

            Button {
                Task { await loadDevices() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    private var navigationTitle: String {
        if viewModel.isLoading { return "Devices" }
        let total = viewModel.devices.count
        let shown = displayedDevices.count
        if !selectedDeviceIDs.isEmpty {
            return "Devices (\(selectedDeviceIDs.count) selected of \(shown))"
        }
        return shown == total ? "Devices (\(total))" : "Devices (\(shown) of \(total))"
    }

    private var devicesForExport: [DeviceAttributes] {
        selectedDeviceIDs.isEmpty
            ? displayedDevices
            : displayedDevices.filter { selectedDeviceIDs.contains($0.serialNumber) }
    }

    private func loadDevices() async {
        do {
            let client = try await appViewModel.ensureConnected()
            await viewModel.loadDevices(client: client)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Filter Panel (ABM-style, popover)

struct FilterPanelView: View {
    @Bindable var filters: DeviceFilters
    @State private var searchText = ""

    private var filteredValues: [String] {
        let values = filters.availableValues[filters.selectedCategory] ?? []
        guard !searchText.isEmpty else { return values }
        return values.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Filters").font(.headline)
                Spacer()
                if filters.hasActiveFilters {
                    Button("Clear All") { filters.clearAll() }
                        .buttonStyle(.borderless).font(.caption)
                }
            }
            .padding()

            Divider()

            HStack(alignment: .top, spacing: 0) {
                // Categories
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(FilterCategory.allCases) { cat in
                        HStack {
                            Text(cat.rawValue).font(.subheadline)
                            Spacer()
                            if filters.isActive(cat) {
                                Circle().fill(.blue).frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(filters.selectedCategory == cat ? Color.accentColor.opacity(0.15) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            filters.selectedCategory = cat
                            searchText = ""
                        }
                    }
                }
                .frame(width: 150)
                .padding(.leading, 8).padding(.top, 8)

                Divider()

                // Values with search
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredValues, id: \.self) { value in
                                let on = filters.selectedValues[filters.selectedCategory]?.contains(value) ?? false
                                HStack(spacing: 8) {
                                    Image(systemName: on ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(on ? .blue : .secondary)
                                    Text(value).font(.subheadline)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { filters.toggle(value: value, in: filters.selectedCategory) }
                            }
                            if filteredValues.isEmpty {
                                Text("No matches").foregroundStyle(.tertiary).font(.caption)
                            }
                        }
                        .padding(8)
                    }
                }
            }
        }
    }
}

// MARK: - Inline Assign/Unassign (Inspector for multi-select)

struct InlineAssignView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var servers: [MdmServerWithId] = []
    @State private var selectedServerName = ""
    @State private var mode: AssignmentMode = .assign
    @State private var isExecuting = false
    @State private var result: ActivityDetails?
    @State private var errorMessage: String?
    let serials: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                Text("\(serials.count) Devices Selected")
                    .font(.title3).fontWeight(.semibold)

                // Serials preview
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(serials.prefix(8), id: \.self) { s in
                        Text(s).font(.caption).fontDesign(.monospaced).foregroundStyle(.secondary)
                    }
                    if serials.count > 8 {
                        Text("+ \(serials.count - 8) more")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // Action
                Picker("Action", selection: $mode) {
                    ForEach(AssignmentMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if servers.isEmpty {
                    ProgressView("Loading servers...").controlSize(.small)
                } else {
                    Picker("Server", selection: $selectedServerName) {
                        Text("Select a server...").tag("")
                        ForEach(servers, id: \.id) { s in
                            Text(s.serverName ?? s.id).tag(s.serverName ?? "")
                        }
                    }
                }

                if let result {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.callout)
                        Text("Activity: \(result.id)")
                            .font(.caption).fontDesign(.monospaced).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        StatusBadge(status: result.status)
                    }
                    .padding(.vertical, 4)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.caption)
                }

                if result == nil {
                    Button {
                        Task { await execute() }
                    } label: {
                        HStack {
                            if isExecuting { ProgressView().controlSize(.small) }
                            Text(mode == .assign ? "Assign" : "Unassign")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(mode == .assign ? .blue : .orange)
                    .disabled(selectedServerName.isEmpty || isExecuting)
                    .controlSize(.large)
                }
            }
            .padding(12)
        }
        .task(id: serials.hashValue) {
            result = nil
            errorMessage = nil
            selectedServerName = ""
            do {
                let client = try await appViewModel.ensureConnected()
                servers = try await client.listMdmServers()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func execute() async {
        isExecuting = true; errorMessage = nil
        do {
            let client = try await appViewModel.ensureConnected()
            let serviceId = try await client.getMdmServerIdByName(selectedServerName)
            let activityType = mode == .assign ? "ASSIGN_DEVICES" : "UNASSIGN_DEVICES"
            result = try await client.createDeviceActivity(
                activityType: activityType, serials: serials, serviceId: serviceId
            )
        } catch { errorMessage = error.localizedDescription }
        isExecuting = false
    }
}
