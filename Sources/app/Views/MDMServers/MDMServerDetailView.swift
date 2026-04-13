import SwiftUI
import ASBMUtilCore

struct MDMServerDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var devices: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    let server: MdmServerWithId

    var filteredDevices: [String] {
        guard !searchText.isEmpty else { return devices }
        return devices.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Server info
            VStack(alignment: .leading, spacing: 4) {
                Text(server.serverName ?? "Server")
                    .font(.headline)
                Text(server.serverType ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(server.id)
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.tertiary)
            }
            .padding()

            Divider()

            if isLoading {
                ProgressView("Loading devices...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding()
                Spacer()
            } else {
                HStack {
                    Text("\(devices.count) devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                List(filteredDevices, id: \.self) { serial in
                    Text(serial)
                        .fontDesign(.monospaced)
                        .font(.callout)
                }
                .searchable(text: $searchText, prompt: "Filter")
            }
        }
        .task(id: server.id) {
            await loadDevices()
        }
    }

    private func loadDevices() async {
        isLoading = true
        errorMessage = nil

        do {
            let client = try await appViewModel.ensureConnected()
            devices = try await client.listMdmServerDevices(serverId: server.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
