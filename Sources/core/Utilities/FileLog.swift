//
//  FileLog.swift
//
//  Append-only file log for small utilities that are invoked by scripts and
//  packages. Console output is unchanged; this file is the audit trail.
//
//  Location   /Library/Managed Utilities/logs/<tool>.log when running as root
//             (the directory is created 0755 root:wheel if missing), otherwise
//             ~/Library/Logs/<tool>.log
//  Line       [yyyy-MM-dd HH:mm:ss] LEVEL  message   (local time, level
//             left-padded to five characters: DEBUG, INFO, WARN, ERROR)
//  Rotation   when a write would take the file past 5 MB it is renamed
//             <tool>.log.1 and older generations shift to .2 .. .5; five
//             generations are kept, newest is .1
//
//  Foundation and libc only. A failure to log is silent so the tool's own
//  behaviour is never affected by the log.
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class FileLog: @unchecked Sendable {

    public enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }

    public static let defaultMaxBytes = 5 * 1024 * 1024
    public static let defaultGenerations = 5
    public static let rootDirectory = "/Library/Managed Utilities/logs"

    public let path: String
    public let maxBytes: Int
    public let generations: Int

    private let lock = NSLock()
    private let formatter: DateFormatter

    /// Logs to the conventional location for `tool` (see the header).
    public convenience init(tool: String) {
        self.init(path: FileLog.defaultPath(tool: tool))
    }

    /// Logs to an explicit path. `maxBytes` and `generations` exist for tests.
    public init(path: String, maxBytes: Int = FileLog.defaultMaxBytes, generations: Int = FileLog.defaultGenerations) {
        self.path = path
        self.maxBytes = Swift.max(1, maxBytes)
        self.generations = Swift.max(0, generations)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.formatter = formatter
    }

    public static func defaultPath(tool: String) -> String {
        if isRoot {
            return rootDirectory + "/" + tool + ".log"
        }
        return NSHomeDirectory() + "/Library/Logs/" + tool + ".log"
    }

    public static var isRoot: Bool {
        return geteuid() == 0
    }

    public func debug(_ message: String) { write(.debug, message) }
    public func info(_ message: String) { write(.info, message) }
    public func warn(_ message: String) { write(.warn, message) }
    public func error(_ message: String) { write(.error, message) }

    public func write(_ level: Level, _ message: String, date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        let line = FileLog.formatLine(level: level, message: message, timestamp: formatter.string(from: date))
        guard let data = line.data(using: .utf8) else { return }
        ensureDirectory()
        append(data)
    }

    /// Builds one log line. Newlines inside `message` are flattened so a
    /// line in the file is always one record.
    public static func formatLine(level: Level, message: String, timestamp: String) -> String {
        let name = level.rawValue
        let padded = String(repeating: " ", count: Swift.max(0, 5 - name.count)) + name
        let flat = message
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "[\(timestamp)] \(padded)  \(flat)\n"
    }

    // MARK: - File handling

    private func ensureDirectory() {
        let directory = (path as NSString).deletingLastPathComponent
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue {
            return
        }
        var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        if FileLog.isRoot {
            attributes[.ownerAccountID] = 0
            attributes[.groupOwnerAccountID] = 0
        }
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: attributes)
    }

    private func append(_ data: Data) {
        var descriptor = openForAppend(path)
        guard descriptor >= 0 else { return }
        let size = Int(lseek(descriptor, 0, SEEK_END))
        if size > 0 && size + data.count > maxBytes {
            close(descriptor)
            rotate()
            descriptor = openForAppend(path)
            guard descriptor >= 0 else { return }
        }
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let written = posixWrite(descriptor, base + offset, buffer.count - offset)
                if written <= 0 { break }
                offset += written
            }
        }
        close(descriptor)
    }

    private func rotate() {
        let manager = FileManager.default
        guard generations > 0 else {
            try? manager.removeItem(atPath: path)
            return
        }
        let oldest = "\(path).\(generations)"
        if manager.fileExists(atPath: oldest) {
            try? manager.removeItem(atPath: oldest)
        }
        if generations > 1 {
            for index in stride(from: generations - 1, through: 1, by: -1) {
                let from = "\(path).\(index)"
                if manager.fileExists(atPath: from) {
                    try? manager.moveItem(atPath: from, toPath: "\(path).\(index + 1)")
                }
            }
        }
        try? manager.moveItem(atPath: path, toPath: "\(path).1")
    }
}

private func openForAppend(_ path: String) -> Int32 {
    return open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
}

private func posixWrite(_ descriptor: Int32, _ pointer: UnsafeRawPointer, _ count: Int) -> Int {
    return write(descriptor, pointer, count)
}
