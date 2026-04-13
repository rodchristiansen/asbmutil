import SwiftUI
import ASBMUtilCore

@main
struct ASBMUtilApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1100, height: 750)
        .commands {
            CommandGroup(after: .saveItem) {
                Menu("Export Devices") {
                    ForEach(ExportFormat.allCases) { fmt in
                        Button("\(fmt.rawValue)...") {
                            Task { @MainActor in
                                await exportAll(format: fmt)
                            }
                        }
                    }
                }
                .disabled(appViewModel.apiClient == nil)
            }
        }

        Settings {
            SettingsView()
                .environment(appViewModel)
        }
    }

    @MainActor
    private func exportAll(format: ExportFormat) async {
        guard let client = appViewModel.apiClient else { return }
        do {
            let devices = try await client.listDevices(devicesPerPage: 1000)
            ExportService.export(devices: devices, format: format)
        } catch {}
    }
}
