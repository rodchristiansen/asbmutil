import Foundation
import ASBMUtilCore

enum FilterCategory: String, CaseIterable, Identifiable {
    case status = "Status"
    case source = "Source"
    case orderNumber = "Order Number"
    case productFamily = "Device Type"
    case capacity = "Storage Size"
    case migration = "Migration"
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
        availableValues[.migration] = uniqueSorted(devices.map(\.migrationSummary))
    }

    func isActive(_ cat: FilterCategory) -> Bool { !(selectedValues[cat]?.isEmpty ?? true) }
    var hasActiveFilters: Bool { selectedValues.values.contains { !$0.isEmpty } }

    func toggle(value: String, in cat: FilterCategory) {
        var s = selectedValues[cat] ?? []
        if s.contains(value) { s.remove(value) } else { s.insert(value) }
        selectedValues[cat] = s
    }

    func setOnly(value: String, in cat: FilterCategory) {
        selectedValues.removeAll()
        selectedValues[cat] = [value]
        selectedCategory = cat
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
            case .migration: v = d.migrationSummary
            }
            guard let v, vals.contains(v) else { return false }
        }
        return true
    }

    private func uniqueSorted(_ v: [String]) -> [String] {
        Array(Set(v)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

extension DeviceAttributes {
    /// One word describing the device's migration state for table and filter use: the Apple
    /// status when a migration exists, otherwise whether the device is eligible at all.
    var migrationSummary: String {
        if let status = mdmMigrationStatus { return status }
        switch isMdmMigrationCapable {
        case .some(true): return "Eligible"
        case .some(false): return "Not eligible"
        case .none: return "Unknown"
        }
    }
}
