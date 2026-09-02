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
/// type-specific `eventData…` object. We decode the common fields plus the device assign/unassign
/// payloads we care about for migration verification; other `eventData…` keys are simply ignored.
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

    // Type-specific event data we surface (device ⇄ server moves).
    public let eventDataDeviceAssignedToServer: AuditEventDeviceServerData?
    public let eventDataDeviceUnassignedFromServer: AuditEventDeviceServerData?
}

/// Event data for `DEVICE_ASSIGNED_TO_SERVER` / `DEVICE_UNASSIGNED_FROM_SERVER`.
///
/// `targetServerName` is only populated for the assigned event; the unassigned event carries the
/// serial alone (Apple doesn't echo the source server in the payload).
public struct AuditEventDeviceServerData: Decodable, Sendable {
    public let serialNumber: String?
    public let targetServerName: String?
}

// MARK: - Flattened record (CLI / reporting output)

/// A migration-friendly flattening of an audit event: the common fields plus the device/server
/// detail pulled out of whichever `eventData…` block applied. This is what callers iterate over to
/// answer "which devices moved to which server, and when".
public struct AuditEventRecord: Codable, Sendable, Identifiable {
    public let id: String
    public let eventDateTime: String?
    public let type: String
    public let outcome: String?
    public let actorName: String?
    public let subjectId: String?
    public let subjectName: String?
    public let serialNumber: String?
    public let targetServerName: String?

    /// Memberwise initializer, for callers building records from cached or exported data rather
    /// than from the wire (the `init(from:)` below otherwise suppresses the synthesized one).
    public init(
        id: String,
        eventDateTime: String?,
        type: String,
        outcome: String?,
        actorName: String?,
        subjectId: String?,
        subjectName: String?,
        serialNumber: String?,
        targetServerName: String?
    ) {
        self.id = id
        self.eventDateTime = eventDateTime
        self.type = type
        self.outcome = outcome
        self.actorName = actorName
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.serialNumber = serialNumber
        self.targetServerName = targetServerName
    }

    public init(from data: AuditEventData) {
        let a = data.attributes
        let deviceData = a.eventDataDeviceAssignedToServer ?? a.eventDataDeviceUnassignedFromServer
        self.id = data.id
        self.eventDateTime = a.eventDateTime
        self.type = a.type
        self.outcome = a.outcome
        self.actorName = a.actorName
        self.subjectId = a.subjectId
        self.subjectName = a.subjectName
        // Device events carry the serial in event data; fall back to the subjectId, which is the
        // device for device-scoped events.
        self.serialNumber = deviceData?.serialNumber ?? (a.subjectType == "DEVICE" ? a.subjectId : nil)
        self.targetServerName = deviceData?.targetServerName
    }
}
