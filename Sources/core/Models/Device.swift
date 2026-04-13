import Foundation

// Helper type to handle fields that can be either a string or an array of strings
public enum StringOrArray: Codable, Sendable, Hashable {
    case string(String)
    case array([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(StringOrArray.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }

    // Convenience properties
    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .array(let values):
            return values.first
        }
    }

    public var allValues: [String] {
        switch self {
        case .string(let value):
            return [value]
        case .array(let values):
            return values
        }
    }
}

public struct OrgDevicesResponse: Decodable, Sendable {
    public let data: [DeviceData]
    public let meta: Meta?
}

public struct Meta: Decodable, Sendable {
    public let paging: Paging
}

public struct Paging: Decodable, Sendable {
    public let nextCursor: String?
}

public struct DeviceData: Decodable, Sendable {
    public let id: String
    public let attributes: DeviceAttributes
}

public struct DeviceAttributes: Codable, Sendable, Identifiable, Hashable {
    public var id: String { serialNumber }

    // Core identifiers
    public let serialNumber: String                 // always present

    // Device information
    public let color: String?                       // The color of the device
    public let deviceCapacity: String?              // The capacity of the device
    public let deviceModel: String?                 // The model name (formerly 'model')
    public let model: String?                       // Legacy field name for backward compatibility

    // Network identifiers - some may be arrays for devices with multiple values
    public let eid: StringOrArray?                  // The device's EID (if available)
    public let imei: StringOrArray?                 // The device's IMEI (if available) - can be array for dual SIM
    public let meid: StringOrArray?                 // The device's MEID (if available)

    // MAC Address attributes (API 1.2 - iOS, iPadOS, tvOS, visionOS; API 1.5 - can be arrays)
    public let wifiMacAddress: StringOrArray?       // The device's Wi-Fi MAC address(es)
    public let bluetoothMacAddress: StringOrArray?  // The device's Bluetooth MAC address(es)

    // MAC Address attributes (API 1.4 - macOS specific; API 1.5 - can be arrays)
    public let builtInEthernetMacAddress: StringOrArray?  // The device's built-in Ethernet MAC address(es)

    // Order and purchase information
    public let orderDateTime: String?               // The date and time of placing the device's order
    public let orderNumber: String?                 // The order number of the device
    public let partNumber: String?                  // The part number of the device
    public let purchaseSourceType: String?          // The device's purchase source type: APPLE, RESELLER, or MANUALLY_ADDED
    public let purchaseSourceId: String?            // The unique ID of the purchase source type

    // Product classification
    public let productFamily: String?               // The device's Apple product family
    public let productType: String?                 // The device's product type (e.g. iPhone14,3)

    // Status and timestamps
    public let status: String?                      // ASSIGNED or UNASSIGNED
    public let addedToOrgDateTime: String?          // The date and time of adding the device to an organization
    public let updatedDateTime: String?             // The date and time of the most-recent update

    // Management
    public let deviceManagementServiceId: String?   // optional - for assigned devices

    private enum CodingKeys: String, CodingKey {
        case serialNumber, color, deviceCapacity, deviceModel, model
        case eid, imei, meid, wifiMacAddress, bluetoothMacAddress, builtInEthernetMacAddress
        case orderDateTime, orderNumber, partNumber, purchaseSourceType, purchaseSourceId
        case productFamily, productType, status, addedToOrgDateTime, updatedDateTime
        case deviceManagementServiceId
    }

    /// Display-friendly model name
    public var displayModel: String {
        deviceModel ?? model ?? "Unknown"
    }
}

/// Combined device info with AppleCare coverage and assigned MDM
public struct DeviceInfo: Encodable, Sendable {
    public let device: DeviceAttributes
    public let appleCareCoverage: [AppleCareAttributes]?
    public let assignedMdm: AssignedMdmInfo?

    public init(device: DeviceAttributes, appleCareCoverage: [AppleCareAttributes]?, assignedMdm: AssignedMdmInfo?) {
        self.device = device
        self.appleCareCoverage = appleCareCoverage
        self.assignedMdm = assignedMdm
    }

    public func encode(to encoder: Encoder) throws {
        // Flatten device attributes into top level
        var container = encoder.container(keyedBy: CodingKeys.self)
        try device.encode(to: encoder)
        if let coverage = appleCareCoverage, !coverage.isEmpty {
            try container.encode(coverage, forKey: .appleCareCoverage)
        }
        if let mdm = assignedMdm {
            try container.encode(mdm, forKey: .assignedMdm)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case appleCareCoverage
        case assignedMdm
    }
}

public struct AssignedMdmInfo: Codable, Sendable {
    public let id: String
    public let serverName: String?
    public let serverType: String?

    public init(id: String, serverName: String?, serverType: String?) {
        self.id = id
        self.serverName = serverName
        self.serverType = serverType
    }
}

public struct MdmServersResponse: Decodable, Sendable {
    public let data: [MdmServerData]
    public let meta: Meta?
}

public struct MdmServerData: Decodable, Sendable {
    public let id: String
    public let attributes: MdmServerAttributes
}

public struct MdmServerAttributes: Codable, Sendable {
    public let serverName: String?
    public let serverType: String?
    public let createdDateTime: String?
    public let updatedDateTime: String?
    public let devices: [String]?
}

public struct MdmServerWithId: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let serverName: String?
    public let serverType: String?
    public let createdDateTime: String?
    public let updatedDateTime: String?

    public init(id: String, serverName: String?, serverType: String?, createdDateTime: String?, updatedDateTime: String?) {
        self.id = id
        self.serverName = serverName
        self.serverType = serverType
        self.createdDateTime = createdDateTime
        self.updatedDateTime = updatedDateTime
    }
}

// MARK: - MDM Server Device Relationships

public struct MdmServerDevicesResponse: Decodable, Sendable {
    public let data: [MdmServerDeviceRef]
    public let links: MdmServerDevicesLinks?
}

public struct MdmServerDeviceRef: Decodable, Sendable {
    public let type: String
    public let id: String          // serial number
}

public struct MdmServerDevicesLinks: Decodable, Sendable {
    public let `self`: String?
    public let next: String?
}

// MARK: - AppleCare Coverage (API 1.3)

public struct AppleCareResponse: Decodable, Sendable {
    public let data: [AppleCareData]
}

public struct AppleCareData: Decodable, Sendable {
    public let id: String
    public let type: String
    public let attributes: AppleCareAttributes
}

public struct AppleCareAttributes: Codable, Sendable {
    public let agreementNumber: String?
    public let description: String?
    public let startDateTime: String?
    public let endDateTime: String?
    public let status: String?
    public let paymentType: String?
    public let isRenewable: Bool?
    public let isCanceled: Bool?
    public let contractCancelDateTime: String?
}

public struct AppleCareCoverage: Codable, Sendable {
    public let deviceSerialNumber: String
    public let coverages: [AppleCareAttributes]
}

// MARK: - Assigned Server Response

public struct AssignedServerResponse: Codable, Sendable {
    public let data: AssignedServerData?
    public let links: AssignedServerLinks?
}

public struct AssignedServerData: Codable, Sendable {
    public let type: String
    public let id: String
}

public struct AssignedServerLinks: Codable, Sendable {
    public let `self`: String
    public let related: String
}

// MARK: - Enhanced Assigned Server Response

public struct EnhancedAssignedServerResponse: Codable, Sendable {
    public let data: EnhancedAssignedServerData?
    public let links: AssignedServerLinks?

    public init(data: EnhancedAssignedServerData?, links: AssignedServerLinks?) {
        self.data = data
        self.links = links
    }
}

public struct EnhancedAssignedServerData: Codable, Sendable {
    public let type: String
    public let id: String
    public let serverName: String?
    public let serverType: String?

    public init(type: String, id: String, serverName: String?, serverType: String?) {
        self.type = type
        self.id = id
        self.serverName = serverName
        self.serverType = serverType
    }
}

// MARK: - Activity Details

public struct ActivityDetails: Codable, Sendable, Identifiable {
    public let id: String
    public let activityType: String
    public let status: String
    public let createdDateTime: String
    public let updatedDateTime: String
    public let deviceCount: Int
    public let deviceSerials: [String]
    public let mdmServerName: String?
    public let mdmServerType: String?
    public let mdmServerId: String

    public init(id: String, activityType: String, status: String, createdDateTime: String, updatedDateTime: String, deviceCount: Int, deviceSerials: [String], mdmServerName: String?, mdmServerType: String?, mdmServerId: String) {
        self.id = id
        self.activityType = activityType
        self.status = status
        self.createdDateTime = createdDateTime
        self.updatedDateTime = updatedDateTime
        self.deviceCount = deviceCount
        self.deviceSerials = deviceSerials
        self.mdmServerName = mdmServerName
        self.mdmServerType = mdmServerType
        self.mdmServerId = mdmServerId
    }
}

// MARK: - Activity Summary (for listing all activities)

public struct ActivitySummary: Codable, Sendable, Identifiable {
    public let id: String
    public let activityType: String
    public let status: String
    public let createdDateTime: String
    public let updatedDateTime: String
    public let deviceCount: Int
    public let deviceSerials: [String]
    public let mdmServerName: String?
    public let mdmServerId: String

    public init(id: String, activityType: String, status: String, createdDateTime: String, updatedDateTime: String, deviceCount: Int, deviceSerials: [String], mdmServerName: String?, mdmServerId: String) {
        self.id = id
        self.activityType = activityType
        self.status = status
        self.createdDateTime = createdDateTime
        self.updatedDateTime = updatedDateTime
        self.deviceCount = deviceCount
        self.deviceSerials = deviceSerials
        self.mdmServerName = mdmServerName
        self.mdmServerId = mdmServerId
    }

    public var displayTitle: String {
        if deviceSerials.count == 1 { return deviceSerials[0] }
        return "Multiple"
    }

    public var displaySubtitle: String {
        let count = deviceCount > 0 ? deviceCount : deviceSerials.count
        let server = mdmServerName ?? mdmServerId
        return "\(count) Device\(count == 1 ? "" : "s") \u{00B7} \(server)"
    }
}

// MARK: - Device MDM Result (for lookup operations)

public struct DeviceMdmResult: Codable, Sendable, Identifiable {
    public var id: String { serialNumber }
    public let serialNumber: String
    public let assignedMdm: AssignedMdmInfo?

    public init(serialNumber: String, assignedMdm: AssignedMdmInfo?) {
        self.serialNumber = serialNumber
        self.assignedMdm = assignedMdm
    }
}
