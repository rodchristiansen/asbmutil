import SwiftUI
import ASBMUtilCore

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Binding var selection: NavigationSection?

    var body: some View {
        @Bindable var vm = appViewModel

        List(selection: $selection) {
            Section("Overview") {
                Label("Dashboard", systemImage: NavigationSection.dashboard.icon)
                    .tag(NavigationSection.dashboard)
            }

            Section("Browse") {
                Label("Devices", systemImage: NavigationSection.devices.icon)
                    .tag(NavigationSection.devices)
                Label("Servers", systemImage: NavigationSection.mdmServers.icon)
                    .tag(NavigationSection.mdmServers)
            }

            Section("Actions") {
                Label("Assignments", systemImage: NavigationSection.assignments.icon)
                    .tag(NavigationSection.assignments)
                Label("Device Lookup", systemImage: NavigationSection.deviceLookup.icon)
                    .tag(NavigationSection.deviceLookup)
                Label("Batch Status", systemImage: NavigationSection.batchStatus.icon)
                    .tag(NavigationSection.batchStatus)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        .safeAreaInset(edge: .bottom) {
            profileSection
        }
    }

    private var profileSection: some View {
        @Bindable var vm = appViewModel
        return VStack(spacing: 4) {
            Divider()
            HStack(spacing: 6) {
                connectionStatusDot
                Picker("Profile", selection: $vm.activeProfile) {
                    if appViewModel.profiles.isEmpty {
                        Text("default").tag("default")
                    }
                    ForEach(appViewModel.profiles, id: \.name) { profile in
                        Text(profile.name).tag(profile.name)
                    }
                }
                .labelsHidden()
                .controlSize(.regular)
                .onChange(of: appViewModel.activeProfile) { _, newValue in
                    Task { await appViewModel.switchProfile(newValue) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var connectionStatusDot: some View {
        Circle()
            .fill(connectionColor)
            .frame(width: 8, height: 8)
    }

    private var connectionColor: Color {
        switch appViewModel.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}
