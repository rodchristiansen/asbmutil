import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class AuditEventsViewModel {
    /// Preset query windows; `.custom` uses the start/end pickers as-is.
    enum Range: String, CaseIterable, Identifiable {
        case day = "Last 24 Hours"
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case quarter = "Last 90 Days"
        case custom = "Custom"

        var id: String { rawValue }

        var interval: TimeInterval? {
            switch self {
            case .day: return 86_400
            case .week: return 7 * 86_400
            case .month: return 30 * 86_400
            case .quarter: return 90 * 86_400
            case .custom: return nil
            }
        }
    }

    var range: Range = .week {
        didSet { applyRange() }
    }
    var startDate = Date().addingTimeInterval(-7 * 86_400)
    var endDate = Date()

    /// Server-side filters. Apple accepts one value each per query.
    var typeFilter: String?
    var subjectId = ""
    var actorId = ""

    /// Client-side filters over the fetched events.
    var searchText = ""
    var outcomeFilter: String?

    private(set) var events: [AuditEventRecord] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastQuery: Date?

    private var loadTask: Task<Void, Never>?

    var displayedEvents: [AuditEventRecord] {
        events.filter { e in
            if let outcomeFilter, e.outcome != outcomeFilter { return false }
            guard !searchText.isEmpty else { return true }
            let fields = [e.type, e.actorName, e.actorId, e.subjectName, e.subjectId,
                          e.serialNumber, e.targetServerName, e.groupId]
            return fields.contains { ($0 ?? "").localizedCaseInsensitiveContains(searchText) }
                || (e.details ?? [:]).values.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var canQuery: Bool { startDate < endDate && !isLoading }

    func applyRange() {
        guard let interval = range.interval else { return }
        endDate = Date()
        startDate = endDate.addingTimeInterval(-interval)
    }

    func load(client: APIClient) {
        loadTask?.cancel()
        // Presets are relative to now, so re-anchor them on every query.
        applyRange()
        let start = Self.iso(startDate), end = Self.iso(endDate)
        let type = typeFilter
        let subject = subjectId.trimmingCharacters(in: .whitespaces)
        let actor = actorId.trimmingCharacters(in: .whitespaces)
        isLoading = true
        errorMessage = nil
        loadTask = Task {
            do {
                let result = try await client.listAuditEvents(
                    startTimestamp: start,
                    endTimestamp: end,
                    type: type,
                    subjectId: subject.isEmpty ? nil : subject,
                    actorId: actor.isEmpty ? nil : actor,
                    eventsPerPage: 1000
                )
                guard !Task.isCancelled else { return }
                events = result
                lastQuery = Date()
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    func reset() {
        cancel()
        events = []
        errorMessage = nil
        lastQuery = nil
    }

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    // MARK: - Export

    static let csvColumns = [
        "eventDateTime", "type", "category", "outcome", "actorType", "actorId", "actorName",
        "subjectType", "subjectId", "subjectName", "groupId", "serialNumber", "targetServerName", "details",
    ]

    static func csv(_ events: [AuditEventRecord], separator: String = ",") -> String {
        func field(_ s: String?) -> String {
            var v = s ?? ""
            // Names and payload values come from the tenant; keep a spreadsheet from reading
            // one that starts with =, +, - or @ as a formula.
            if let first = v.first, "=+-@\t\r".contains(first) { v = "'" + v }
            if separator == "\t" { return v.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
            return v.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline })
                ? "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : v
        }
        let rows = events.map { e -> String in
            let details = (e.details ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            return [e.eventDateTime, e.type, e.category, e.outcome, e.actorType, e.actorId, e.actorName,
                    e.subjectType, e.subjectId, e.subjectName, e.groupId, e.serialNumber, e.targetServerName, details]
                .map(field).joined(separator: separator)
        }
        return ([csvColumns.joined(separator: separator)] + rows).joined(separator: "\n") + "\n"
    }

    static func json(_ events: [AuditEventRecord]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(events)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }
}
