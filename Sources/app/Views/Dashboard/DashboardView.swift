import SwiftUI
import Charts
import ASBMUtilCore

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let onSelectFilter: (FilterCategory, String) -> Void

    private var stats: DashboardStats {
        DashboardStats(
            devices: appViewModel.devices,
            servers: appViewModel.mdmServers,
            serverCounts: appViewModel.serverDeviceCounts
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if appViewModel.isLoadingDevices && appViewModel.devices.isEmpty {
                    loadingPlaceholder
                } else if let error = appViewModel.deviceLoadError, appViewModel.devices.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't load dashboard", systemImage: "exclamationmark.triangle")
                    } description: { Text(error) } actions: {
                        Button("Retry") { Task { await appViewModel.refreshDevices() } }
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else if appViewModel.devices.isEmpty {
                    ContentUnavailableView("No Devices",
                                           systemImage: "chart.bar.xaxis",
                                           description: Text("Connect a profile to see metrics."))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    statStrip
                    MasonryLayout(columnSpacing: 16, rowSpacing: 16, minColumnWidth: 360) {
                        statusCard
                        serverCard
                        productFamilyCard
                        capacityCard
                        timelineCard
                        topOrdersCard
                        sourceCard
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await appViewModel.refreshDevices() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appViewModel.isLoadingDevices)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task {
            if appViewModel.devices.isEmpty && !appViewModel.isLoadingDevices {
                await appViewModel.loadDevices()
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading data...").foregroundStyle(.secondary).font(.callout)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Stat Strip

    private var statStrip: some View {
        let s = stats
        let assignedPct = s.total == 0 ? 0 : Int(round(Double(s.assigned) / Double(s.total) * 100))
        return HStack(spacing: 12) {
            StatTile(label: "Total Devices", value: "\(s.total)",
                     accent: .blue, systemImage: "desktopcomputer")
            StatTile(label: "Assigned", value: "\(s.assigned)",
                     accent: .green, systemImage: "checkmark.seal",
                     secondary: "\(assignedPct)%")
            StatTile(label: "Unassigned", value: "\(s.unassigned)",
                     accent: .orange, systemImage: "questionmark.diamond",
                     secondary: s.total == 0 ? nil : "\(100 - assignedPct)%")
            StatTile(label: "Orders", value: "\(s.uniqueOrders)",
                     accent: .pink, systemImage: "shippingbox")
            StatTile(label: "Servers", value: "\(s.serversInUse)",
                     accent: .indigo, systemImage: "server.rack")
        }
    }

    // MARK: - Cards

    private var statusCard: some View {
        DashboardCard(title: "Status", subtitle: "Assigned vs Unassigned") {
            if stats.statusBins.isEmpty {
                emptyChart
            } else {
                Chart(stats.statusBins) { bin in
                    SectorMark(
                        angle: .value("Count", bin.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Status", bin.label))
                }
                .chartForegroundStyleScale([
                    "ASSIGNED": Color.green,
                    "UNASSIGNED": Color.orange
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .frame(height: 200)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(stats.statusBins) { bin in
                        FilterRow(
                            label: bin.label,
                            count: bin.count,
                            total: stats.total,
                            color: bin.label == "ASSIGNED" ? .green : .orange
                        ) {
                            onSelectFilter(.status, bin.label)
                        }
                    }
                }
            }
        }
    }

    private var sourceCard: some View {
        DashboardCard(title: "Source", subtitle: "Where devices came from") {
            filterRowList(stats.sourceBins, category: .source, accent: .blue)
        }
    }

    private var productFamilyCard: some View {
        DashboardCard(title: "Device Type", subtitle: "Apple product family") {
            filterRowList(stats.productFamilyBins, category: .productFamily, accent: .purple)
        }
    }

    private var capacityCard: some View {
        DashboardCard(title: "Storage Size", subtitle: "Capacity distribution") {
            if stats.capacityBins.isEmpty && stats.unknownCapacityCount == 0 {
                emptyChart
            } else if stats.capacityBins.isEmpty {
                Text("\(stats.unknownCapacityCount) device\(stats.unknownCapacityCount == 1 ? "" : "s") with no reported capacity.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(stats.capacityBins) { bin in
                    BarMark(
                        x: .value("Capacity", bin.label),
                        y: .value("Count", bin.count)
                    )
                    .foregroundStyle(Color.yellow.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(orientation: .vertical, horizontalSpacing: 4)
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                handleTap(location: location, geo: geo, proxy: proxy,
                                          bins: stats.capacityBins, category: .capacity)
                            }
                    }
                }

                if stats.unknownCapacityCount > 0 {
                    Text("\(stats.unknownCapacityCount) device\(stats.unknownCapacityCount == 1 ? "" : "s") with no reported capacity (accessories, Apple TV, etc.).")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var serverCard: some View {
        DashboardCard(title: "Devices per Server", subtitle: "Top servers by assignment") {
            if stats.serverBins.isEmpty {
                if appViewModel.isLoadingServerCounts {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Counting devices per server...").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ContentUnavailableView("No assignments yet",
                                           systemImage: "server.rack",
                                           description: Text("Assigned devices will appear here."))
                        .frame(height: 160)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(stats.serverBins) { bin in
                        FilterRow(
                            label: bin.label,
                            count: bin.count,
                            total: stats.serverBins.first?.count ?? 0,
                            color: .indigo
                        ) { /* server filtering not wired into Devices view */ }
                    }
                }
            }
        }
    }

    private var timelineCard: some View {
        DashboardCard(title: "Recently Added", subtitle: "Devices added per month (last 12 months)") {
            if stats.timelineBins.allSatisfy({ $0.count == 0 }) {
                ContentUnavailableView("No recent activity",
                                       systemImage: "calendar",
                                       description: Text("No devices added in the last year."))
                    .frame(height: 200)
            } else {
                Chart(stats.timelineBins) { bin in
                    BarMark(
                        x: .value("Month", bin.date, unit: .month),
                        y: .value("Count", bin.count)
                    )
                    .foregroundStyle(Color.mint.gradient)
                    .cornerRadius(3)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private var topOrdersCard: some View {
        DashboardCard(title: "Top Orders", subtitle: "Largest orders by device count") {
            if stats.topOrderBins.isEmpty {
                emptyChart
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(stats.topOrderBins) { bin in
                        FilterRow(
                            label: bin.label,
                            count: bin.count,
                            total: stats.topOrderBins.first?.count ?? 0,
                            color: .pink
                        ) {
                            if let v = bin.filterValue { onSelectFilter(.orderNumber, v) }
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func filterRowList(_ bins: [DashboardBin], category: FilterCategory, accent: Color) -> some View {
        if bins.isEmpty {
            emptyChart
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bins) { bin in
                    FilterRow(
                        label: bin.label,
                        count: bin.count,
                        total: bins.first?.count ?? 0,
                        color: accent
                    ) {
                        if let v = bin.filterValue { onSelectFilter(category, v) }
                    }
                }
            }
        }
    }

    private var emptyChart: some View {
        Text("No data").foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func handleTap(
        location: CGPoint,
        geo: GeometryProxy,
        proxy: ChartProxy,
        bins: [DashboardBin],
        category: FilterCategory
    ) {
        guard let plotFrame = proxy.plotFrame else { return }
        let plot = geo[plotFrame]
        guard plot.contains(location) else { return }
        let label: String? = proxy.value(atX: location.x - plot.minX, as: String.self)
        if let label, let bin = bins.first(where: { $0.label == label }),
           let v = bin.filterValue {
            onSelectFilter(category, v)
        }
    }
}

// MARK: - Sub-components

struct StatTile: View {
    let label: String
    let value: String
    var accent: Color = .accentColor
    var systemImage: String
    var secondary: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .shadow(color: accent.opacity(0.35), radius: 4, x: 0, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(.title3).fontWeight(.semibold).monospacedDigit()
                    if let secondary {
                        Text(secondary).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5)
        )
    }
}

struct DashboardCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 0.5)
        )
    }
}

struct FilterRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    let action: () -> Void

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(count) / Double(total))
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 8)
                Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
            }
            .font(.callout)
            .padding(.vertical, 5).padding(.horizontal, 10)
            .background(
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [color.opacity(0.65), color.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * ratio)
                        Spacer(minLength: 0)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
