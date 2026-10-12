import Foundation

// MARK: - Audit Events (API 2.0)

/// Wire response for `GET /v1/auditEvents`.
///
/// Apple paginates this endpoint two ways depending on the deployment: a `meta.paging.nextCursor`
/// (same shape as `orgDevices`) and/or a `links.next` URL. We decode both and let the client prefer
/// whichever is present so pagination keeps working if Apple changes which one it populates.
public struct AuditEventsResponse: Decodable, Sendable {
    public let data: [AuditEventData]
    public let meta: Meta?
    public let links: AuditEventLinks?
}

public struct AuditEventLinks: Decodable, Sendable {
    public let `self`: String?
    public let next: String?
}

public struct AuditEventData: Decodable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let attributes: AuditEventAttributes
}

/// Audit-event attributes.
///
/// Apple models this polymorphically — every event shares the common fields and carries one
/// type-specific `eventData…` object, named by `eventDataPropertyKey`. We decode the common fields,
/// the device assign/unassign payloads used for migration verification, and every `eventData…`
/// object as a generic JSON value so new event types Apple adds still surface their detail.
public struct AuditEventAttributes: Decodable, Sendable {
    // Common attributes (AuditEventCommonAttributes)
    public let eventDateTime: String?
    public let type: String
    public let category: String?
    public let actorType: String?
    public let actorId: String?
    public let actorName: String?
    public let subjectType: String?
    public let subjectId: String?
    public let subjectName: String?
    public let outcome: String?
    public let groupId: String?
    public let eventDataPropertyKey: String?

    // Type-specific event data we surface (device ⇄ server moves).
    public let eventDataDeviceAssignedToServer: AuditEventDeviceServerData?
    public let eventDataDeviceUnassignedFromServer: AuditEventDeviceServerData?

    /// Every `eventData…` object on the event, keyed by its property name.
    public let eventData: [String: JSONValue]

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func str(_ k: String) throws -> String? { try c.decodeIfPresent(String.self, forKey: Key(k)) }
        eventDateTime = try str("eventDateTime")
        type = try c.decode(String.self, forKey: Key("type"))
        category = try str("category")
        actorType = try str("actorType")
        actorId = try str("actorId")
        actorName = try str("actorName")
        subjectType = try str("subjectType")
        subjectId = try str("subjectId")
        subjectName = try str("subjectName")
        outcome = try str("outcome")
        groupId = try str("groupId")
        eventDataPropertyKey = try str("eventDataPropertyKey")
        eventDataDeviceAssignedToServer = try? c.decodeIfPresent(AuditEventDeviceServerData.self, forKey: Key("eventDataDeviceAssignedToServer"))
        eventDataDeviceUnassignedFromServer = try? c.decodeIfPresent(AuditEventDeviceServerData.self, forKey: Key("eventDataDeviceUnassignedFromServer"))

        var data: [String: JSONValue] = [:]
        for key in c.allKeys where key.stringValue.hasPrefix("eventData") && key.stringValue != "eventDataPropertyKey" {
            if let value = try? c.decode(JSONValue.self, forKey: key), value != .null {
                data[key.stringValue] = value
            }
        }
        eventData = data
    }
}

/// Event data for `DEVICE_ASSIGNED_TO_SERVER` / `DEVICE_UNASSIGNED_FROM_SERVER`.
///
/// `targetServerName` is only populated for the assigned event; the unassigned event carries the
/// serial alone (Apple doesn't echo the source server in the payload).
public struct AuditEventDeviceServerData: Decodable, Sendable {
    public let serialNumber: String?
    public let targetServerName: String?
}

/// A generic JSON value, for payloads whose shape varies by event type.
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }

    /// Flatten into dotted `key: value` pairs for display (`account.email`, `roles[0]`).
    public func flattened(prefix: String = "") -> [(key: String, value: String)] {
        switch self {
        case .object(let o):
            return o.keys.sorted().flatMap { k in
                o[k]!.flattened(prefix: prefix.isEmpty ? k : "\(prefix).\(k)")
            }
        case .array(let a):
            if a.isEmpty { return [(prefix, "[]")] }
            return a.enumerated().flatMap { i, v in v.flattened(prefix: "\(prefix)[\(i)]") }
        case .string(let s): return [(prefix, s)]
        case .number(let n): return [(prefix, n == n.rounded() && abs(n) < 1e15 ? String(Int64(n)) : String(n))]
        case .bool(let b): return [(prefix, b ? "true" : "false")]
        case .null: return [(prefix, "null")]
        }
    }
}

// MARK: - Flattened record (CLI / reporting output)

/// A flattening of an audit event: the common fields, the device/server detail pulled out of the
/// device move events (the basis for migration verification), and the type-specific event data.
public struct AuditEventRecord: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let eventDateTime: String?
    public let type: String
    public let category: String?
    public let outcome: String?
    public let actorType: String?
    public let actorId: String?
    public let actorName: String?
    public let subjectType: String?
    public let subjectId: String?
    public let subjectName: String?
    public let groupId: String?
    public let serialNumber: String?
    public let targetServerName: String?
    /// The event-specific payload flattened to dotted keys, e.g. `domainName` or `roles[0]`.
    public let details: [String: String]?

    public init(
        id: String,
        eventDateTime: String?,
        type: String,
        category: String? = nil,
        outcome: String?,
        actorType: String? = nil,
        actorId: String? = nil,
        actorName: String?,
        subjectType: String? = nil,
        subjectId: String?,
        subjectName: String?,
        groupId: String? = nil,
        serialNumber: String?,
        targetServerName: String?,
        details: [String: String]? = nil
    ) {
        self.id = id
        self.eventDateTime = eventDateTime
        self.type = type
        self.category = category
        self.outcome = outcome
        self.actorType = actorType
        self.actorId = actorId
        self.actorName = actorName
        self.subjectType = subjectType
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.groupId = groupId
        self.serialNumber = serialNumber
        self.targetServerName = targetServerName
        self.details = details
    }

    public init(from data: AuditEventData) {
        let a = data.attributes
        let deviceData = a.eventDataDeviceAssignedToServer ?? a.eventDataDeviceUnassignedFromServer
        // Prefer the payload Apple names in eventDataPropertyKey; fall back to whatever single
        // eventData object is present.
        let payload = a.eventDataPropertyKey.flatMap { a.eventData[$0] } ?? a.eventData.values.first
        let flat = payload?.flattened() ?? []
        self.init(
            id: data.id,
            eventDateTime: a.eventDateTime,
            type: a.type,
            category: a.category ?? AuditEventCatalog.category(for: a.type),
            outcome: a.outcome,
            actorType: a.actorType,
            actorId: a.actorId,
            actorName: a.actorName,
            subjectType: a.subjectType,
            subjectId: a.subjectId,
            subjectName: a.subjectName,
            groupId: a.groupId,
            // Device events carry the serial in event data; fall back to the subjectId, which is
            // the device for device-scoped events.
            serialNumber: deviceData?.serialNumber ?? (a.subjectType == "DEVICE" ? a.subjectId : nil),
            targetServerName: deviceData?.targetServerName,
            details: flat.isEmpty ? nil : Dictionary(flat.map { ($0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
        )
    }

    /// The event time as a `Date`, for sorting and display.
    public var date: Date? { eventDateTime.flatMap(APIClient.parseISO8601) }
}

// MARK: - Event catalog

/// The event types Apple documents for `AuditEventType`, grouped by `AuditEventCategory`.
///
/// Used to offer a type filter and readable titles. Apple adds types over time (2.6 added
/// identity-service events), so anything not listed here still decodes and displays by raw value.
public enum AuditEventCatalog {
    public static let categories: [(category: String, types: [String])] = [
        ("DEVICE_INVENTORY", [
            "DEVICE_ADDED_TO_ORG", "DEVICE_REMOVED_FROM_ORG", "DEVICE_IS_ERASED",
        ]),
        ("DEVICE_MANAGEMENT", [
            "DEVICE_ASSIGNED_TO_SERVER", "DEVICE_UNASSIGNED_FROM_SERVER",
            "CONFIG_SETTINGS_CREATED", "CONFIG_SETTINGS_UPDATED", "CONFIG_SETTINGS_DELETED",
            "COLLECTION_CREATED", "COLLECTION_UPDATED", "COLLECTION_DELETED",
        ]),
        ("PURCHASING", [
            "SUBJECT_HAS_ICLOUD_STORAGE_PURCHASE_ADDED", "SUBJECT_HAS_ICLOUD_STORAGE_PURCHASE_REMOVED",
            "SUBJECT_HAS_APPLECARE_PURCHASE_ADDED", "SUBJECT_HAS_APPLECARE_PURCHASE_REMOVED",
            "SUBSCRIPTION_CREATED", "SUBSCRIPTION_UPDATED", "SUBSCRIPTION_DELETED",
        ]),
        ("ACCOUNT_ACTIVITY", [
            "ACCOUNT_ADDED", "ACCOUNT_DELETED", "ACCOUNT_ROLE_LOCATION_CHANGED",
            "ACCOUNT_PASSWORD_CHANGED", "BATCH_PASSWORD_RESET_INITIATED",
            "ACCOUNT_IMAGE_SET", "ACCOUNT_IMAGE_REPLACED", "ACCOUNT_IMAGE_REMOVED",
            "EXTERNAL_ACCOUNT_ASSOCIATED", "EXTERNAL_ACCOUNT_DISASSOCIATED", "EXTERNAL_ACCOUNT_INVITED",
            "API_ACCOUNT_CREATED_WITH_KEY", "API_ACCOUNT_CREATED_WITHOUT_KEY", "API_ACCOUNT_DELETED",
            "API_ACCOUNT_KEY_GENERATED", "API_ACCOUNT_KEY_REVOKED",
            "API_ACCOUNT_ROLE_LOCATION_CHANGED", "API_ACCOUNT_NAME_CHANGED",
            "APPLE_SERVICES_SETTINGS_UPDATED", "ROLE_CREATED", "ROLE_UPDATED",
        ]),
        ("ORGANIZATION", [
            "TERMS_ACCEPTED", "DOMAIN_ADDED", "DOMAIN_REMOVED", "DOMAIN_VERIFIED",
            "DOMAIN_FEDERATION_ENABLED", "DOMAIN_FEDERATION_DISABLED",
            "IDP_CREATED", "IDP_UPDATED", "IDP_DELETED",
            "IDP_ACCOUNT_SYNC_ENABLED", "IDP_ACCOUNT_SYNC_DISABLED",
        ]),
    ]

    private static let categoryByType: [String: String] = Dictionary(
        categories.flatMap { entry in entry.types.map { ($0, entry.category) } },
        uniquingKeysWith: { a, _ in a }
    )

    public static var allTypes: [String] { categories.flatMap(\.types) }

    public static func category(for type: String) -> String? { categoryByType[type] }

    /// `DEVICE_ASSIGNED_TO_SERVER` → "Device Assigned To Server", with Apple's acronyms kept.
    public static func title(for raw: String) -> String {
                return raw.split(separator: "_").map { word in
            let w = String(word)
            if w == "ICLOUD" { return "iCloud" }
            if w == "APPLECARE" { return "AppleCare" }
            if w == "IDP" { return "IdP" }
            return w == "API" ? w : w.capitalized
        }.joined(separator: " ")
    }
}
