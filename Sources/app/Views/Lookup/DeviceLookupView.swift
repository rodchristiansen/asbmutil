import SwiftUI
import UniformTypeIdentifiers
import ASBMUtilCore

struct DeviceLookupView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = DeviceLookupViewModel()
    @State private var showFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Input area
            GroupBox("Serial Numbers") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Serial numbers (comma-separated)", text: $viewModel.serialInput)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.monospaced)
                        .disabled(!viewModel.importedSerials.isEmpty)

                    HStack {
                        Button("Look Up") {
                            Task { await lookup() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.serialNumbers.isEmpty || viewModel.isLoading)

                        if viewModel.isLoading {
                            ProgressView().controlSize(.small)
                        }

                        Button("Import CSV") { showFilePicker = true }

                        if !viewModel.importedSerials.isEmpty {
                            Text("\(viewModel.importedSerials.count) serials imported")
                                .foregroundStyle(.secondary).font(.caption)
                            Button("Clear") { viewModel.importedSerials.removeAll() }
                                .buttonStyle(.borderless).font(.caption)
                        }

                        Spacer()
                    }
                }
            }
            .padding()

            Divider()

            // Results
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).font(.caption).padding()
                Spacer()
            } else if !viewModel.results.isEmpty {
                Text("\(viewModel.assignedCount)/\(viewModel.results.count) devices have server assignments")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal).padding(.top, 8)

                Table(viewModel.results) {
                    TableColumn("Serial") { (r: DeviceMdmResult) in
                        Text(r.serialNumber).fontDesign(.monospaced)
                    }.width(min: 110, ideal: 140)

                    TableColumn("Server") { (r: DeviceMdmResult) in
                        Text(r.assignedMdm?.serverName ?? "Not assigned")
                            .foregroundStyle(r.assignedMdm != nil ? .primary : .secondary)
                    }.width(min: 100, ideal: 160)

                    TableColumn("Type") { (r: DeviceMdmResult) in
                        Text(r.assignedMdm?.serverType ?? "-")
                    }.width(min: 60, ideal: 100)

                    TableColumn("Server ID") { (r: DeviceMdmResult) in
                        Text(r.assignedMdm?.id ?? "-")
                            .fontDesign(.monospaced).font(.caption)
                    }.width(min: 80, ideal: 200)
                }
            } else {
                Spacer()
            }
        }
        .navigationTitle("Device Lookup")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importCSV(from: url)
            }
        }
    }

    private func lookup() async {
        do {
            let client = try await appViewModel.ensureConnected()
            await viewModel.lookup(client: client)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
