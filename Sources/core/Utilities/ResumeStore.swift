import Foundation

/// Persistent snapshot of a paginated `list-devices` pull so a failed run can be resumed.
public struct ListDevicesResumeState: Codable, Sendable {
    public let profile: String
    public let cursor: String?
    public let devices: [DeviceAttributes]
    public let devicesPerPage: Int?
    public let totalLimit: Int?
    public let pagesCompleted: Int
    public let savedAt: Date

    public init(
        profile: String,
        cursor: String?,
        devices: [DeviceAttributes],
        devicesPerPage: Int?,
        totalLimit: Int?,
        pagesCompleted: Int,
        savedAt: Date = Date()
    ) {
        self.profile = profile
        self.cursor = cursor
        self.devices = devices
        self.devicesPerPage = devicesPerPage
        self.totalLimit = totalLimit
        self.pagesCompleted = pagesCompleted
        self.savedAt = savedAt
    }
}

/// File-backed store for a single profile's `list-devices` resume state.
///
/// Layout: `~/.config/asbmutil/state/<profile>-list-devices.json`. The directory is created on
/// first write. Reads return nil when the file is missing so `--resume` on a fresh run is a no-op
/// rather than an error.
public struct ResumeStore: Sendable {
    public let profile: String
    private let fileURL: URL

    public init(profile: String) throws {
        self.profile = profile
        self.fileURL = try Self.fileURL(for: profile)
    }

    public func load() throws -> ListDevicesResumeState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ListDevicesResumeState.self, from: data)
    }

    public func save(_ state: ListDevicesResumeState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public var path: String { fileURL.path }

    private static func fileURL(for profile: String) throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safe = profile.replacingOccurrences(of: "/", with: "_")
        return home
            .appendingPathComponent(".config/asbmutil/state", isDirectory: true)
            .appendingPathComponent("\(safe)-list-devices.json")
    }
}
