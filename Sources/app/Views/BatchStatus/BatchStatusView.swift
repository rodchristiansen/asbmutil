import SwiftUI
import ASBMUtilCore

struct BatchStatusView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = BatchStatusViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Input area
            GroupBox("Activity") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Activity ID", text: $viewModel.activityId)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.monospaced)

                    HStack {
                        Button("Check Status") {
                            Task { await checkOnce() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canCheck)

                        if viewModel.isPolling {
                            Button("Stop Polling") { viewModel.stopPolling() }
                                .buttonStyle(.bordered)
                                .tint(.red)
                        } else {
                            Button("Start Polling") {
                                Task { await startPolling() }
                            }
                            .disabled(!viewModel.canCheck)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            LabeledContent("Interval") {
                                Stepper("\(viewModel.pollInterval)s", value: $viewModel.pollInterval, in: 1...120)
                            }
                            LabeledContent("Timeout") {
                                Stepper("\(viewModel.pollTimeout)s", value: $viewModel.pollTimeout, in: 10...3600, step: 30)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            .padding()

            if !viewModel.status.isEmpty {
                HStack {
                    Text("Status:")
                        .font(.headline)
                    StatusBadge(status: viewModel.status)
                }
                .padding(.horizontal)
            }

            if viewModel.isChecking {
                ProgressView().controlSize(.small).padding(.horizontal)
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Divider().padding(.top, 8)

            // Poll log
            if !viewModel.pollLog.isEmpty {
                Text("Poll Log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)

                List(viewModel.pollLog) { entry in
                    HStack {
                        Text(entry.timestamp, style: .time)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        StatusBadge(status: entry.status)
                    }
                }
            } else {
                Spacer()
            }
        }
        .navigationTitle("Batch Status")
    }

    private func checkOnce() async {
        do {
            let client = try await appViewModel.ensureConnected()
            await viewModel.checkOnce(client: client)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func startPolling() async {
        do {
            let client = try await appViewModel.ensureConnected()
            viewModel.startPolling(client: client)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
