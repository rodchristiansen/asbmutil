import SwiftUI
import UniformTypeIdentifiers
import ASBMUtilCore

private extension AuditEventRecord {
    var sortDate: Date { date ?? .distantPast }
    var sortOutcome: String { outcome ?? "" }
    var actorDisplay: String { actorName ?? actorId ?? "" }
    var subjectDisplay: String { subjectName ?? subjectId ?? "" }
    var typeTitle: String { AuditEventCatalog.title(for: type) }

    /// One-line summary of the event-specific payload for the table.
    var detailSummary: String {
        if let serialNumber, let targetServerName { return "\(serialNumber) → \(targetServerName)" }
        return (details ?? [:]).sorted { $0.key < $1.key }.prefix(3)
            .map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

struct AuditEventsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = AuditEventsViewModel()
    @State private var selection: Set<String> = []
    @State private var showingInspector = false
    @State private var sortOrder = [KeyPathComparator(\AuditEventRecord.sortDate, order: .reverse)]
    @State private var checkedTenant = false
    @AppStorage("auditEvents.range") private var storedRange = AuditEventsViewModel.Range.week.rawValue
    @SceneStorage("auditEvents.columns") private var columnCustomization = TableColumnCustomization<AuditEventRecord>()

    private var sortedEvents: [AuditEventRecord] {
        viewModel.displayedEvents.sorted(using: sortOrder)
    }

    private var selectedEvents: [AuditEventRecord] {
        viewModel.events.filter { selection.contains($0.id) }
    }

    var body: some View {
        content
            .navigationTitle("Audit Events")
            .navigationSubtitle(subtitle)
            .searchable(text: $viewModel.searchText, prompt: "Filter results")
            .toolbar { toolbar }
            .inspector(isPresented: $showingInspector) {
                inspector.inspectorColumnWidth(min: 320, ideal: 400, max: 560)
            }
            .onChange(of: selection) { _, new in
                if new.count == 1 { showingInspector = true }
            }
            .onChange(of: viewModel.range) { _, new in storedRange = new.rawValue }
            .onChange(of: appViewModel.activeProfile) { _, _ in
                viewModel.reset()
                selection = []
                checkedTenant = false
            }
            .task(id: appViewModel.activeProfile) { await firstLoad() }
    }

    private var subtitle: String {
        guard !viewModel.events.isEmpty else { return "" }
        let shown = viewModel.displayedEvents.count, total = viewModel.events.count
        return shown == total ? "\(total) events" : "\(shown) of \(total) events"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if checkedTenant && !appViewModel.isBusinessTenant && appViewModel.apiClient != nil {
            ContentUnavailableView {
                Label("Apple Business Only", systemImage: "building.2")
            } description: {
                Text("Audit events are part of the Apple Business API. The profile “\(appViewModel.activeProfile)” is an Apple School Manager credential, which doesn’t offer this endpoint.")
            }
        } else {
            VStack(spacing: 0) {
                queryBar
                Divider()
                results
            }
        }
    }

    private var queryBar: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Picker("Range", selection: $vm.range) {
                    ForEach(AuditEventsViewModel.Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .fixedSize()

                DatePicker("From", selection: $vm.startDate, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: viewModel.startDate) { markCustomIfEdited() }
                DatePicker("To", selection: $vm.endDate, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: viewModel.endDate) { markCustomIfEdited() }
                Spacer()
            }
            HStack(spacing: 12) {
                Picker("Type", selection: $vm.typeFilter) {
                    Text("All Types").tag(String?.none)
                    ForEach(AuditEventCatalog.categories, id: \.category) { entry in
                        Section(AuditEventCatalog.title(for: entry.category)) {
                            ForEach(entry.types, id: \.self) { type in
                                Text(AuditEventCatalog.title(for: type)).tag(String?.some(type))
                            }
                        }
                    }
                }
                .fixedSize()

                TextField("Subject ID", text: $vm.subjectId, prompt: Text("Subject ID (e.g. serial)"))
                    .frame(maxWidth: 220)
                    .onSubmit(query)
                TextField("Actor ID", text: $vm.actorId, prompt: Text("Actor ID"))
                    .frame(maxWidth: 220)
                    .onSubmit(query)

                Spacer()

                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                    Button("Stop", action: viewModel.cancel)
                        .keyboardShortcut(".", modifiers: .command)
                }
                Button("Query", action: query)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canQuery)
                    .help("Fetch events for the range and filters (⌘↩)")
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(12)
    }

    @ViewBuilder
    private var results: some View {
        if let error = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn’t Load Audit Events", systemImage: "exclamationmark.triangle")
            } description: { Text(error) } actions: {
                Button("Try Again", action: query)
            }
        } else if viewModel.isLoading && viewModel.events.isEmpty {
            ProgressView("Loading audit events…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.lastQuery != nil && viewModel.events.isEmpty {
            ContentUnavailableView("No Events", systemImage: "list.bullet.clipboard",
                                   description: Text("Nothing matched this range and filter."))
        } else if viewModel.lastQuery == nil {
            ContentUnavailableView("No Query Yet", systemImage: "list.bullet.clipboard",
                                   description: Text("Choose a range and press Query (⌘↩)."))
        } else {
            table
        }
    }

    private var table: some View {
        Table(sortedEvents, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("Date", value: \.sortDate) { (e: AuditEventRecord) in
                if let d = e.date {
                    Text(d, format: .dateTime.year().month(.abbreviated).day().hour().minute().second())
                        .monospacedDigit()
                } else {
                    Text(e.eventDateTime ?? "")
                }
            }
            .width(min: 140, ideal: 170)
            .customizationID("date")

            TableColumn("Event", value: \.typeTitle) { (e: AuditEventRecord) in
                Text(e.typeTitle).help(e.type)
            }
            .width(min: 140, ideal: 220)
            .customizationID("type")

            TableColumn("Category", value: \AuditEventRecord.category.orEmpty) { (e: AuditEventRecord) in
                Text(AuditEventCatalog.title(for: e.category ?? ""))
            }
            .width(min: 90, ideal: 130)
            .customizationID("category")
            .defaultVisibility(.hidden)

            TableColumn("Outcome", value: \.sortOutcome) { (e: AuditEventRecord) in
                if let outcome = e.outcome { StatusBadge(status: outcome) }
            }
            .width(min: 70, ideal: 90)
            .customizationID("outcome")

            TableColumn("Actor", value: \.actorDisplay) { (e: AuditEventRecord) in
                Text(e.actorDisplay).help(e.actorId ?? "")
            }
            .width(min: 100, ideal: 170)
            .customizationID("actor")

            TableColumn("Subject", value: \.subjectDisplay) { (e: AuditEventRecord) in
                Text(e.subjectDisplay).help(e.subjectId ?? "")
            }
            .width(min: 100, ideal: 170)
            .customizationID("subject")

            TableColumn("Details", value: \.detailSummary) { (e: AuditEventRecord) in
                Text(e.detailSummary).foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 260)
            .customizationID("details")
        }
        .contextMenu(forSelectionType: String.self) { ids in
            contextMenu(for: ids)
        } primaryAction: { ids in
            if ids.count == 1 { selection = ids; showingInspector = true }
        }
        .onCopyCommand { copyProviders(for: selectedEvents) }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<String>) -> some View {
        let events = viewModel.events.filter { ids.contains($0.id) }
        Button("Copy") { copy(events, format: .tsv) }
        Button("Copy as JSON") { copy(events, format: .json) }
        if events.count == 1, let e = events.first {
            Divider()
            if let subject = e.subjectId {
                Button("Copy Subject ID") { copyString(subject) }
                Button("Show Events for This Subject") { requery { viewModel.subjectId = subject } }
            }
            if let actor = e.actorId {
                Button("Copy Actor ID") { copyString(actor) }
                Button("Show Events by This Actor") { requery { viewModel.actorId = actor } }
            }
            Button("Show Only “\(e.typeTitle)” Events") { requery { viewModel.typeFilter = e.type } }
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspector: some View {
        if selection.count == 1, let e = selectedEvents.first {
            AuditEventDetailView(event: e)
        } else {
            ContentUnavailableView(selection.isEmpty ? "No Selection" : "\(selection.count) Events Selected",
                                   systemImage: "sidebar.right")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Outcome", selection: $viewModel.outcomeFilter) {
                Text("All Outcomes").tag(String?.none)
                Text("Success").tag(String?.some("SUCCESS"))
                Text("Failure").tag(String?.some("FAILURE"))
            }
            .help("Show only events with this outcome")

            Menu {
                Button("CSV…") { export(.csv) }
                Button("TSV…") { export(.tsv) }
                Button("JSON…") { export(.json) }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export the events shown")
            .disabled(viewModel.displayedEvents.isEmpty)

            Button(action: query) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .help("Run the query again (⌘R)")
            .disabled(!viewModel.canQuery)

            Button { showingInspector.toggle() } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help("Show or hide the event inspector (⌥⌘I)")
        }
    }

    // MARK: - Actions

    private func firstLoad() async {
        if let saved = AuditEventsViewModel.Range(rawValue: storedRange) { viewModel.range = saved }
        do {
            _ = try await appViewModel.ensureConnected()
        } catch {
            checkedTenant = false
            return
        }
        checkedTenant = true
        if appViewModel.isBusinessTenant, viewModel.lastQuery == nil { query() }
    }

    private func query() {
        Task {
            do {
                let client = try await appViewModel.ensureConnected()
                guard appViewModel.isBusinessTenant else { checkedTenant = true; return }
                selection = []
                viewModel.load(client: client)
            } catch {
                viewModel.reset()
            }
        }
    }

    private func requery(_ change: () -> Void) {
        change()
        query()
    }

    /// Editing a date by hand switches the range to Custom, so the next query keeps it.
    private func markCustomIfEdited() {
        guard viewModel.range != .custom, let interval = viewModel.range.interval else { return }
        let expected = viewModel.endDate.timeIntervalSince(viewModel.startDate)
        if abs(expected - interval) > 60 || abs(viewModel.endDate.timeIntervalSinceNow) > 120 {
            viewModel.range = .custom
        }
    }

    private enum Format { case csv, tsv, json }

    private func render(_ events: [AuditEventRecord], _ format: Format) -> String {
        switch format {
        case .csv: return AuditEventsViewModel.csv(events)
        case .tsv: return AuditEventsViewModel.csv(events, separator: "\t")
        case .json: return AuditEventsViewModel.json(events)
        }
    }

    private func export(_ format: Format) {
        let content = render(sortedEvents, format)
        let panel = NSSavePanel()
        switch format {
        case .csv: panel.allowedContentTypes = [.commaSeparatedText]; panel.nameFieldStringValue = "audit-events.csv"
        case .tsv: panel.allowedContentTypes = [.tabSeparatedText]; panel.nameFieldStringValue = "audit-events.tsv"
        case .json: panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "audit-events.json"
        }
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func copy(_ events: [AuditEventRecord], format: Format) {
        guard !events.isEmpty else { return }
        copyString(render(events.sorted(using: sortOrder), format))
    }

    private func copyString(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func copyProviders(for events: [AuditEventRecord]) -> [NSItemProvider] {
        guard !events.isEmpty else { return [] }
        return [NSItemProvider(object: render(events.sorted(using: sortOrder), .tsv) as NSString)]
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

// MARK: - Detail

struct AuditEventDetailView: View {
    let event: AuditEventRecord

    var body: some View {
        Form {
            Section("Event") {
                row("Type", AuditEventCatalog.title(for: event.type), raw: event.type)
                row("Category", event.category.map(AuditEventCatalog.title(for:)), raw: event.category)
                if let d = event.date {
                    LabeledContent("Date") {
                        Text(d, format: .dateTime.year().month().day().hour().minute().second().timeZone())
                            .textSelection(.enabled)
                    }
                }
                if let outcome = event.outcome {
                    LabeledContent("Outcome") { StatusBadge(status: outcome) }
                }
                row("Event ID", event.id)
                row("Group ID", event.groupId)
            }
            Section("Actor") {
                row("Name", event.actorName)
                row("Type", event.actorType)
                row("ID", event.actorId)
            }
            Section("Subject") {
                row("Name", event.subjectName)
                row("Type", event.subjectType)
                row("ID", event.subjectId)
                row("Serial Number", event.serialNumber)
                row("Target Server", event.targetServerName)
            }
            if let details = event.details, !details.isEmpty {
                Section("Event Data") {
                    ForEach(details.keys.sorted(), id: \.self) { key in
                        row(key, details[key])
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?, raw: String? = nil) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label) {
                Text(value)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .help(raw ?? value)
            }
            .contextMenu {
                Button("Copy \(label)") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(raw ?? value, forType: .string)
                }
            }
        }
    }
}
