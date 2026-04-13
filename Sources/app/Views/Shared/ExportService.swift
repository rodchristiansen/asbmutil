import SwiftUI
import UniformTypeIdentifiers
import ASBMUtilCore

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    case tsv = "TSV"
    case plist = "Property List"
    case serials = "Serial Numbers"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .tsv: return "tsv"
        case .plist: return "plist"
        case .serials: return "txt"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
        case .tsv: return .tabSeparatedText
        case .plist: return .propertyList
        case .serials: return .plainText
        }
    }

    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .tsv: return "tablecells.badge.ellipsis"
        case .plist: return "doc.text"
        case .serials: return "list.number"
        }
    }
}

enum ExportService {
    @MainActor static func export(devices: [DeviceAttributes], format: ExportFormat) {
        let content = generate(devices: devices, format: format)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "devices.\(format.fileExtension)"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    @MainActor static func copyToClipboard(devices: [DeviceAttributes], format: ExportFormat) {
        let content = generate(devices: devices, format: format)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    static func generate(devices: [DeviceAttributes], format: ExportFormat) -> String {
        switch format {
        case .csv: return generateCSV(devices)
        case .json: return generateJSON(devices)
        case .tsv: return generateTSV(devices)
        case .plist: return generatePlist(devices)
        case .serials: return devices.map(\.serialNumber).joined(separator: "\n")
        }
    }

    private static let columns = [
        "Serial Number", "Model", "Product Family", "Product Type", "Status",
        "Storage", "Color", "Source", "Order Number", "Part Number",
        "Order Date", "Added", "Updated"
    ]

    private static func values(for d: DeviceAttributes) -> [String] {
        [d.serialNumber, d.displayModel, d.productFamily ?? "", d.productType ?? "",
         d.status ?? "", d.deviceCapacity ?? "", d.color ?? "",
         d.purchaseSourceType ?? "", d.orderNumber ?? "", d.partNumber ?? "",
         d.orderDateTime ?? "", d.addedToOrgDateTime ?? "", d.updatedDateTime ?? ""]
    }

    private static func generateCSV(_ devices: [DeviceAttributes]) -> String {
        var out = columns.joined(separator: ",") + "\n"
        for d in devices {
            out += values(for: d).map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: ",") + "\n"
        }
        return out
    }

    private static func generateTSV(_ devices: [DeviceAttributes]) -> String {
        var out = columns.joined(separator: "\t") + "\n"
        for d in devices {
            out += values(for: d).joined(separator: "\t") + "\n"
        }
        return out
    }

    private static func generateJSON(_ devices: [DeviceAttributes]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(devices),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func generatePlist(_ devices: [DeviceAttributes]) -> String {
        let dicts: [[String: String]] = devices.map { d in
            Dictionary(uniqueKeysWithValues: zip(columns, values(for: d)))
        }
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dicts, format: .xml, options: 0
        ), let str = String(data: data, encoding: .utf8) else { return "" }
        return str
    }
}
