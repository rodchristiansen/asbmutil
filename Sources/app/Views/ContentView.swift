import SwiftUI
import ASBMUtilCore

enum NavigationSection: String, Hashable, CaseIterable {
    case dashboard = "Dashboard"
    case devices = "Devices"
    case mdmServers = "Servers"
    case assignments = "Assignments"
    case deviceLookup = "Device Lookup"
    case batchStatus = "Batch Status"

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.xaxis"
        case .devices: return "desktopcomputer"
        case .mdmServers: return "server.rack"
        case .assignments: return "arrow.left.arrow.right"
        case .deviceLookup: return "magnifyingglass"
        case .batchStatus: return "clock.arrow.circlepath"
        }
    }
}

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedSection: NavigationSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView { category, value in
                    appViewModel.deviceFilters.setOnly(value: value, in: category)
                    selectedSection = .devices
                }
            case .devices:
                DeviceListView()
            case .mdmServers:
                MDMServerListView()
            case .assignments:
                AssignmentView()
            case .deviceLookup:
                DeviceLookupView()
            case .batchStatus:
                BatchStatusView()
            case nil:
                ContentUnavailableView("Select a Section", systemImage: "sidebar.left",
                                       description: Text("Choose a section from the sidebar."))
            }
        }
    }
}
