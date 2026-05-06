import Foundation
import ASBMUtilCore

struct DashboardBin: Identifiable, Hashable {
    let label: String
    let count: Int
    let filterValue: String?
    /// Stable identifier for ForEach/Charts. Defaults to `label` for value-keyed
    /// bins (status, source, etc.) where labels are unique by construction; for
    /// server bins we explicitly pass the server id so duplicate server names
    /// don't collapse rows or crash the chart.
    let idKey: String
    var id: String { idKey }

    init(label: String, count: Int, filterValue: String?, idKey: String? = nil) {
        self.label = label
        self.count = count
        self.filterValue = filterValue
        self.idKey = idKey ?? label
    }
}

struct TimelineBin: Identifiable, Hashable {
    let date: Date
    let count: Int
    var id: Date { date }
}

struct DashboardStats {
    let total: Int
    let assigned: Int
    let unassigned: Int
    let uniqueOrders: Int
    let serversInUse: Int
    let unknownCapacityCount: Int
    let statusBins: [DashboardBin]
    let sourceBins: [DashboardBin]
    let productFamilyBins: [DashboardBin]
    let capacityBins: [DashboardBin]
    let topOrderBins: [DashboardBin]
    let serverBins: [DashboardBin]
    let timelineBins: [TimelineBin]

    static let empty = DashboardStats(
        total: 0, assigned: 0, unassigned: 0, uniqueOrders: 0, serversInUse: 0,
        unknownCapacityCount: 0,
        statusBins: [], sourceBins: [], productFamilyBins: [],
        capacityBins: [], topOrderBins: [], serverBins: [], timelineBins: []
    )

    init(
        total: Int, assigned: Int, unassigned: Int, uniqueOrders: Int, serversInUse: Int,
        unknownCapacityCount: Int,
        statusBins: [DashboardBin], sourceBins: [DashboardBin], productFamilyBins: [DashboardBin],
        capacityBins: [DashboardBin], topOrderBins: [DashboardBin],
        serverBins: [DashboardBin], timelineBins: [TimelineBin]
    ) {
        self.total = total
        self.assigned = assigned
        self.unassigned = unassigned
        self.uniqueOrders = uniqueOrders
        self.serversInUse = serversInUse
        self.unknownCapacityCount = unknownCapacityCount
        self.statusBins = statusBins
        self.sourceBins = sourceBins
        self.productFamilyBins = productFamilyBins
        self.capacityBins = capacityBins
        self.topOrderBins = topOrderBins
        self.serverBins = serverBins
        self.timelineBins = timelineBins
    }

    init(devices: [DeviceAttributes], servers: [MdmServerWithId], serverCounts: [String: Int]) {
        let total = devices.count

        let statusCounts = Self.bin(devices, key: \.status)
        let assigned = statusCounts.first { $0.label == "ASSIGNED" }?.count ?? 0
        let unassigned = statusCounts.first { $0.label == "UNASSIGNED" }?.count ?? 0

        let orderCounts = Self.bin(devices, key: \.orderNumber)
        let uniqueOrders = orderCounts.count

        let serverNameById: [String: String] = Dictionary(
            uniqueKeysWithValues: servers.map { ($0.id, $0.serverName ?? $0.id) }
        )

        let rawServerBins = serverCounts
            .filter { $0.value > 0 }
            .map { (id, count) in
                DashboardBin(
                    label: serverNameById[id] ?? id,
                    count: count,
                    filterValue: nil,
                    idKey: id
                )
            }
            .sorted { $0.count > $1.count }

        let (capacityBins, unknownCapacity) = Self.binCapacity(devices)

        self.init(
            total: total,
            assigned: assigned,
            unassigned: unassigned,
            uniqueOrders: uniqueOrders,
            serversInUse: rawServerBins.count,
            unknownCapacityCount: unknownCapacity,
            statusBins: statusCounts,
            sourceBins: Self.bin(devices, key: \.purchaseSourceType),
            productFamilyBins: Self.bin(devices, key: \.productFamily),
            capacityBins: capacityBins,
            topOrderBins: Array(orderCounts.prefix(10)),
            serverBins: Array(rawServerBins.prefix(10)),
            timelineBins: Self.timeline(devices)
        )
    }

    private static func bin(_ devices: [DeviceAttributes], key: KeyPath<DeviceAttributes, String?>) -> [DashboardBin] {
        let groups = Dictionary(grouping: devices.compactMap { $0[keyPath: key] }) { $0 }
        return groups
            .map { DashboardBin(label: $0.key, count: $0.value.count, filterValue: $0.key) }
            .sorted { $0.count > $1.count }
    }

    /// ASBM returns "Unknown" (or empty) capacity for accessories and devices it can't probe.
    /// We split those out so the chart only shows real storage sizes; the count is reported
    /// separately as a footnote.
    private static func binCapacity(_ devices: [DeviceAttributes]) -> ([DashboardBin], Int) {
        let raw = devices.compactMap { $0.deviceCapacity }
        var unknown = 0
        var sized: [String] = []
        for value in raw {
            if isUnknownCapacity(value) { unknown += 1 } else { sized.append(value) }
        }
        let bins = Dictionary(grouping: sized) { $0 }
            .map { DashboardBin(label: $0.key, count: $0.value.count, filterValue: $0.key) }
            .sorted { capacityRank($0.label) < capacityRank($1.label) }
        return (bins, unknown)
    }

    private static func isUnknownCapacity(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        let upper = trimmed.uppercased()
        if upper == "UNKNOWN" || upper == "N/A" { return true }
        return !(upper.contains("GB") || upper.contains("TB") || upper.contains("MB"))
    }

    /// Rough numeric sort for capacities like "64GB", "256GB", "1TB", "2TB".
    private static func capacityRank(_ s: String) -> Double {
        let upper = s.uppercased()
        let digits = upper.filter { $0.isNumber || $0 == "." }
        let value = Double(digits) ?? 0
        if upper.contains("TB") { return value * 1024 }
        if upper.contains("GB") { return value }
        if upper.contains("MB") { return value / 1024 }
        return value
    }

    private static func timeline(_ devices: [DeviceAttributes]) -> [TimelineBin] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        guard let currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let startMonth = cal.date(byAdding: .month, value: -11, to: currentMonth) else {
            return []
        }

        var counts: [Date: Int] = [:]
        for device in devices {
            guard let raw = device.addedToOrgDateTime else { continue }
            let date = formatter.date(from: raw) ?? fallback.date(from: raw)
            guard let date else { continue }
            let comp = cal.dateComponents([.year, .month], from: date)
            guard let bucket = cal.date(from: comp), bucket >= startMonth else { continue }
            counts[bucket, default: 0] += 1
        }

        var bins: [TimelineBin] = []
        for offset in 0..<12 {
            guard let bucket = cal.date(byAdding: .month, value: offset, to: startMonth) else { continue }
            bins.append(TimelineBin(date: bucket, count: counts[bucket] ?? 0))
        }
        return bins
    }
}
