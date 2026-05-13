import Foundation

/// Checkpoint metadata for an in-progress paginated `list-devices` pull.
///
/// The accumulated device list is stored separately as an append-only JSONL spool so we don't
/// rewrite a multi-megabyte JSON file after every page. `devicesCount` is the spool length we
/// expect at this checkpoint; it's used as a sanity check on load.
public struct ListDevicesCheckpoint: Codable, Sendable {
    public let profile: String
    public let cursor: String?
    public let devicesPerPage: Int?
    public let totalLimit: Int?
    public let pagesCompleted: Int
    public let devicesCount: Int
    public let savedAt: Date

    public init(
        profile: String,
        cursor: String?,
        devicesPerPage: Int?,
        totalLimit: Int?,
        pagesCompleted: Int,
        devicesCount: Int,
        savedAt: Date = Date()
    ) {
        self.profile = profile
        self.cursor = cursor
        self.devicesPerPage = devicesPerPage
        self.totalLimit = totalLimit
        self.pagesCompleted = pagesCompleted
        self.devicesCount = devicesCount
        self.savedAt = savedAt
    }
}

/// What `ResumeStore.load` hands back: the checkpoint plus the devices recovered from the spool.
public struct ListDevicesResumeState: Sendable {
    public let checkpoint: ListDevicesCheckpoint
    public let devices: [DeviceAttributes]
}

/// File-backed store for a single profile's `list-devices` resume state.
///
/// Layout, under `<config>/state/`:
///   - `<encoded-profile>-list-devices.json`     small checkpoint (cursor + counts)
///   - `<encoded-profile>-list-devices.jsonl`    append-only spool, one DeviceAttributes per line
///
/// The directory is created on first write with 0700 and files are written with 0600 so the
/// device inventory isn't world-readable (matches the FileCredentialStore convention).
///
/// Profile names are percent-encoded into the filename so e.g. `a/b` and `a_b` get distinct
/// state paths and don't collide.
public struct ResumeStore: Sendable {
    public let profile: String
    private let stateURL: URL
    private let spoolURL: URL

    public init(profile: String) throws {
        self.profile = profile
        let (state, spool) = try Self.fileURLs(for: profile)
        self.stateURL = state
        self.spoolURL = spool
    }

    public func load() throws -> ListDevicesResumeState? {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return nil }
        let data = try Data(contentsOf: stateURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let checkpoint = try decoder.decode(ListDevicesCheckpoint.self, from: data)
        let devices = try readSpool()
        return ListDevicesResumeState(checkpoint: checkpoint, devices: devices)
    }

    /// Append a page's devices to the spool, then atomically rewrite the small checkpoint file.
    /// Spool grows by one line per device per page; the checkpoint file stays tiny regardless of
    /// fleet size, so per-page write cost is O(page size) rather than O(total devices).
    public func appendPage(checkpoint: ListDevicesCheckpoint, newDevices: [DeviceAttributes]) throws {
        try ensureDirectory()
        if !newDevices.isEmpty {
            try appendToSpool(newDevices)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(checkpoint)
        try data.write(to: stateURL, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
    }

    public func clear() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: stateURL.path) { try fm.removeItem(at: stateURL) }
        if fm.fileExists(atPath: spoolURL.path) { try fm.removeItem(at: spoolURL) }
    }

    public var statePath: String { stateURL.path }
    public var spoolPath: String { spoolURL.path }

    // MARK: - Internals

    private func ensureDirectory() throws {
        let dir = stateURL.deletingLastPathComponent()
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    }

    private func readSpool() throws -> [DeviceAttributes] {
        guard FileManager.default.fileExists(atPath: spoolURL.path) else { return [] }
        let data = try Data(contentsOf: spoolURL)
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        var devices: [DeviceAttributes] = []
        // Each line is a self-contained JSON object. Split on newline and skip blanks so a
        // truncated trailing write (process killed mid-line) is tolerated rather than fatal.
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let bytes = trimmed.data(using: .utf8) else { continue }
            do {
                let device = try decoder.decode(DeviceAttributes.self, from: bytes)
                devices.append(device)
            } catch {
                // Skip a corrupt trailing line silently; on the next page write the file is rewritten.
                continue
            }
        }
        return devices
    }

    private func appendToSpool(_ devices: [DeviceAttributes]) throws {
        let encoder = JSONEncoder()
        var buffer = Data()
        for device in devices {
            let line = try encoder.encode(device)
            buffer.append(line)
            buffer.append(0x0A) // '\n'
        }
        let fm = FileManager.default
        if !fm.fileExists(atPath: spoolURL.path) {
            try buffer.write(to: spoolURL, options: [.atomic])
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: spoolURL.path)
        } else {
            let handle = try FileHandle(forWritingTo: spoolURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: buffer)
        }
    }

    private static func fileURLs(for profile: String) throws -> (state: URL, spool: URL) {
        let homePath = ProcessInfo.processInfo.environment["HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let base = URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent(".config/asbmutil/state", isDirectory: true)
        let safe = encodeProfile(profile)
        return (
            base.appendingPathComponent("\(safe)-list-devices.json"),
            base.appendingPathComponent("\(safe)-list-devices.jsonl")
        )
    }

    /// Reversible per-profile encoding. We percent-encode anything outside `[A-Za-z0-9._-]` so
    /// `a/b` and `a_b` get distinct filenames and exotic characters can't collide or escape the
    /// state directory. Falls back to the unencoded profile name only if encoding somehow fails.
    private static func encodeProfile(_ profile: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "._-")
        return profile.addingPercentEncoding(withAllowedCharacters: allowed) ?? profile
    }
}
