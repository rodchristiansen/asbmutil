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

    // Device management service migration (API 1.6 School / 2.3 Business). Read-only; all three
    // are absent unless the tenant serves the migration release. `mdmMigrationStatus` and the
    // deadline are only populated once a migration has been requested for the device.
    public let isMdmMigrationCapable: Bool?         // Whether the device is eligible for migration
    public let mdmMigrationStatus: String?          // REQUESTED, STARTED, SUCCESS, or FAILED
    public let mdmMigrationDeadlineDateTime: String? // ISO 8601 deadline for the migration

    // Release (API 2.4 Business). Only populated on single-device reads; absent from the list call.
    public let releasedFromOrgDateTime: String?

    private enum CodingKeys: String, CodingKey {
        case serialNumber, color, deviceCapacity, deviceModel, model
        case eid, imei, meid, wifiMacAddress, bluetoothMacAddress, builtInEthernetMacAddress
        case orderDateTime, orderNumber, partNumber, purchaseSourceType, purchaseSourceId
        case productFamily, productType, status, addedToOrgDateTime, updatedDateTime
        case deviceManagementServiceId
        case isMdmMigrationCapable, mdmMigrationStatus, mdmMigrationDeadlineDateTime
        case releasedFromOrgDateTime
    }

    /// True while Apple reports a migration that has not yet finished (REQUESTED or STARTED).
    public var hasActiveMdmMigration: Bool {
        MdmMigrationStatus(rawValue: mdmMigrationStatus ?? "")?.isActive ?? false
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

// MARK: - Device Verification (pre-flight existence check)

/// Outcome of pre-flight `GET /v1/orgDevices/{id}` checks before an assign/unassign.
///
/// `found` are serials Apple confirmed exist in the org (HTTP 200) and are safe to submit.
/// `notFound` are serials Apple reports don't exist (HTTP 404) — not yet registered by the
/// reseller, or mistyped. `errored` are serials whose existence couldn't be determined
/// (any other status after retries); they are excluded from submission and surfaced so the
/// operator can retry rather than have a possibly-valid device silently dropped.
public struct DeviceVerification: Sendable {
    public let found: [String]
    public let notFound: [String]
    public let errored: [(serial: String, message: String)]

    public init(found: [String], notFound: [String], errored: [(serial: String, message: String)]) {
        self.found = found
        self.notFound = notFound
        self.errored = errored
    }
}

// MARK: - Post-assignment Confirmation

/// The end state a confirmation check expects each serial to be in, carrying the target server id.
public enum AssignmentExpectation: Sendable {
    /// Device should now report this server as its assigned MDM (after an assign).
    case assigned(serverId: String)
    /// Device should no longer be on this server (after an unassign).
    case unassigned(serverId: String)
}

/// Outcome of re-querying each serial's assigned MDM after an activity reached a terminal state.
///
/// `asExpected` are serials whose current assignment matches the intended end state. `mismatched`
/// are serials that settled in a different state than intended (`assignedTo` is the server id they
/// currently report, or nil if unassigned). `errored` are serials whose assignment couldn't be read.
public struct AssignmentReconciliation: Sendable {
    public let asExpected: [String]
    public let mismatched: [(serial: String, assignedTo: String?)]
    public let errored: [(serial: String, message: String)]

    public init(asExpected: [String], mismatched: [(serial: String, assignedTo: String?)], errored: [(serial: String, message: String)]) {
        self.asExpected = asExpected
        self.mismatched = mismatched
        self.errored = errored
    }
}

// MARK: - Organization Device Activity Types

/// The `activityType` values accepted by `POST /v1/orgDeviceActivities`.
///
/// The first two exist on every API version. The three migration types arrived with School 1.6 /
/// Business 2.3 (changelog 2026-08-12) and `RELEASE_DEVICES` with Business 2.4 (2026-08-26). Apple
/// serves the School Manager release on a rolling basis, so a School tenant can still reject the
/// migration types with a 4xx even though they are documented.
public enum DeviceActivityType: String, Codable, Sendable, CaseIterable {
    case assignDevices = "ASSIGN_DEVICES"
    case unassignDevices = "UNASSIGN_DEVICES"
    /// Assign devices to a device management service and schedule a no-erase migration by a deadline.
    case assignDevicesWithMdmMigrationDeadline = "ASSIGN_DEVICES_WITH_MDM_MIGRATION_DEADLINE"
    /// Move the deadline of an in-progress migration. An earlier or past deadline is enforced immediately.
    case updateMdmMigrationDeadline = "UPDATE_MDM_MIGRATION_DEADLINE"
    /// Cancel an in-progress migration.
    case cancelMdmMigration = "CANCEL_MDM_MIGRATION"
    /// Release devices from the organization entirely (Apple Business only; irreversible).
    case releaseDevices = "RELEASE_DEVICES"

    /// Whether the request must carry an `mdmServer` relationship.
    public var requiresMdmServer: Bool {
        switch self {
        case .assignDevices, .unassignDevices, .assignDevicesWithMdmMigrationDeadline: return true
        case .updateMdmMigrationDeadline, .cancelMdmMigration, .releaseDevices: return false
        }
    }

    /// Whether the request must carry `activityTypeMetadata.mdmMigrationDeadlineDateTime`.
    public var requiresMigrationDeadline: Bool {
        switch self {
        case .assignDevicesWithMdmMigrationDeadline, .updateMdmMigrationDeadline: return true
        default: return false
        }
    }

    /// Whether the type is part of the device-management-service migration feature.
    public var isMigrationType: Bool {
        switch self {
        case .assignDevicesWithMdmMigrationDeadline, .updateMdmMigrationDeadline, .cancelMdmMigration: return true
        default: return false
        }
    }

    /// Whether the type exists only on the Apple Business API.
    public var isBusinessOnly: Bool { self == .releaseDevices }
}

/// `MdmMigrationStatus` — the per-device migration state Apple reports once a migration is requested.
public enum MdmMigrationStatus: String, Codable, Sendable, CaseIterable {
    case requested = "REQUESTED"   // Requested but the device hasn't started
    case started = "STARTED"       // The device has started migrating
    case success = "SUCCESS"       // The device completed the migration
    case failed = "FAILED"         // The device failed to complete the migration

    /// A migration that is still pending on the device.
    public var isActive: Bool { self == .requested || self == .started }
}

/// Apple rejects migration deadlines more than this many days in the future.
public let mdmMigrationDeadlineMaxDays = 90

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
    /// The target device management service. Nil for activity types that carry no server
    /// relationship (update/cancel migration, release).
    public let mdmServerId: String?
    /// The migration deadline submitted with the activity, when one was.
    public let mdmMigrationDeadlineDateTime: String?

    public init(id: String, activityType: String, status: String, createdDateTime: String, updatedDateTime: String, deviceCount: Int, deviceSerials: [String], mdmServerName: String?, mdmServerType: String?, mdmServerId: String?, mdmMigrationDeadlineDateTime: String? = nil) {
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
        self.mdmMigrationDeadlineDateTime = mdmMigrationDeadlineDateTime
    }
}

// MARK: - Device Management Service Migration (API 1.6 School / 2.3 Business)

/// One device's migration state as read back from `GET /v1/orgDevices/{serial}`.
public struct MdmMigrationRecord: Codable, Sendable, Identifiable {
    public var id: String { serialNumber }
    public let serialNumber: String
    public let isMdmMigrationCapable: Bool?
    public let mdmMigrationStatus: String?
    public let mdmMigrationDeadlineDateTime: String?
    public let status: String?                      // ASSIGNED or UNASSIGNED
    public let deviceManagementServiceId: String?
    /// Set when the device could not be read; the other fields are then nil.
    public let error: String?

    public init(serialNumber: String, isMdmMigrationCapable: Bool?, mdmMigrationStatus: String?, mdmMigrationDeadlineDateTime: String?, status: String?, deviceManagementServiceId: String?, error: String? = nil) {
        self.serialNumber = serialNumber
        self.isMdmMigrationCapable = isMdmMigrationCapable
        self.mdmMigrationStatus = mdmMigrationStatus
        self.mdmMigrationDeadlineDateTime = mdmMigrationDeadlineDateTime
        self.status = status
        self.deviceManagementServiceId = deviceManagementServiceId
        self.error = error
    }

    public init(device d: DeviceAttributes) {
        self.init(
            serialNumber: d.serialNumber,
            isMdmMigrationCapable: d.isMdmMigrationCapable,
            mdmMigrationStatus: d.mdmMigrationStatus,
            mdmMigrationDeadlineDateTime: d.mdmMigrationDeadlineDateTime,
            status: d.status,
            deviceManagementServiceId: d.deviceManagementServiceId
        )
    }

    public var hasActiveMigration: Bool {
        MdmMigrationStatus(rawValue: mdmMigrationStatus ?? "")?.isActive ?? false
    }
}

/// The end state a migration confirmation expects each device to report.
public enum MigrationExpectation: Sendable {
    /// A migration is pending (REQUESTED or STARTED) with this deadline.
    case scheduled(deadline: String)
    /// No migration is pending (after a cancel).
    case cancelled
}

/// Outcome of re-reading each device's migration state after an activity settled.
public struct MigrationReconciliation: Sendable {
    public let asExpected: [MdmMigrationRecord]
    public let mismatched: [MdmMigrationRecord]
    public let errored: [(serial: String, message: String)]

    public init(asExpected: [MdmMigrationRecord], mismatched: [MdmMigrationRecord], errored: [(serial: String, message: String)]) {
        self.asExpected = asExpected
        self.mismatched = mismatched
        self.errored = errored
    }
}

// MARK: - Release (API 2.4 Business)

/// Outcome of re-reading each serial after a `RELEASE_DEVICES` activity settled.
///
/// A released device disappears from the organization, so `released` are serials Apple now reports
/// as not found (HTTP 404) or with `releasedFromOrgDateTime` set. `stillPresent` still read back as
/// org devices. `errored` could not be read.
public struct ReleaseReconciliation: Sendable {
    public let released: [String]
    public let stillPresent: [String]
    public let errored: [(serial: String, message: String)]

    public init(released: [String], stillPresent: [String], errored: [(serial: String, message: String)]) {
        self.released = released
        self.stillPresent = stillPresent
        self.errored = errored
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
