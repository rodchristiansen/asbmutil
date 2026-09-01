import ArgumentParser
import ASBMUtilCore
import Foundation

let log = FileLog(tool: "asbmutil")

@main
struct ASBMUtil: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "asbmutil",
        abstract: "Apple School & Business Manager CLI \(AppVersion.version)",
        version: AppVersion.version,
        subcommands: [
            Config.self,
            ListDevices.self,
            ListDevicesServers.self,
            ListMdmServers.self,
            GetDevicesInfo.self,
            Assign.self,
            Unassign.self,
            BatchStatus.self,
            // Hidden aliases for backward compatibility
            GetDeviceInfoAlias.self,
            GetDeviceAlias.self,
            GetAssignedMdm.self,
        ]
    )

    /// Same flow as the default `AsyncParsableCommand.main()`, with the
    /// invocation, its outcome and any error written to the file log.
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let invocation = InvocationRecord(arguments: arguments)
        log.info("invoked \(invocation.description)")
        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            log.info("completed \(invocation.command) exit=0")
        } catch {
            let code = exitCode(for: error)
            if code.isSuccess {
                log.info("completed \(invocation.command) exit=\(code.rawValue)")
            } else {
                let detail = InvocationRecord.redactedMessage(message(for: error))
                let phase = code == .validationFailure ? "rejected" : "failed"
                log.error("\(phase) \(invocation.command) exit=\(code.rawValue) reason=\(detail)")
            }
            exit(withError: error)
        }
    }
}

// MARK: - Invocation logging

/// The command path and arguments as they will appear in the log, with any
/// value that may carry a credential replaced by a placeholder.
struct InvocationRecord {
    let command: String
    let arguments: [String]

    static let sensitiveOptionFragments = ["key", "secret", "token", "password", "pem", "private", "credential"]
    static let placeholder = "[redacted]"

    init(arguments: [String]) {
        let path = InvocationRecord.commandPath(for: arguments)
        self.command = path.isEmpty ? "asbmutil" : path.joined(separator: " ")
        self.arguments = InvocationRecord.redacted(arguments.dropFirst(path.count))
    }

    var description: String {
        return arguments.isEmpty ? command : "\(command) \(arguments.joined(separator: " "))"
    }

    /// Walks the subcommand tree so `config set --profile x` is recorded as
    /// `config set` and `batch-status <id>` as `batch-status`.
    static func commandPath(for arguments: [String]) -> [String] {
        var path: [String] = []
        var candidates: [ParsableCommand.Type] = ASBMUtil.configuration.subcommands
        for argument in arguments {
            if argument.hasPrefix("-") { break }
            guard let match = candidates.first(where: { $0._commandName == argument }) else { break }
            path.append(argument)
            candidates = match.configuration.subcommands
        }
        return path
    }

    static func isSensitive(optionName: String) -> Bool {
        let lowered = optionName.lowercased()
        return sensitiveOptionFragments.contains { lowered.contains($0) }
    }

    static func redacted<S: Sequence>(_ arguments: S) -> [String] where S.Element == String {
        var result: [String] = []
        var redactNext = false
        for argument in arguments {
            if redactNext {
                result.append(placeholder)
                redactNext = false
                continue
            }
            if argument.hasPrefix("-") {
                if let separator = argument.firstIndex(of: "=") {
                    let name = String(argument[..<separator])
                    result.append(isSensitive(optionName: name) ? "\(name)=\(placeholder)" : argument)
                } else {
                    result.append(argument)
                    redactNext = isSensitive(optionName: argument)
                }
            } else if looksLikeSecret(argument) {
                result.append(placeholder)
            } else {
                result.append(argument)
            }
        }
        return result
    }

    static func looksLikeSecret(_ value: String) -> Bool {
        return value.contains("-----BEGIN") || value.count > 200
    }

    /// Error text goes to the log on one line and never carries key material.
    static func redactedMessage(_ message: String) -> String {
        var text = message
        if let range = text.range(of: "-----BEGIN") {
            text = String(text[..<range.lowerBound]) + placeholder
        }
        if text.count > 500 {
            text = String(text.prefix(500)) + "..."
        }
        return text
    }
}

// MARK: - Hidden backward-compatible aliases

struct GetDeviceInfoAlias: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get-device-info",
        abstract: "Alias for get-devices-info",
        shouldDisplay: false
    )
    @Option(name: .customLong("serials"), help: "One or more serial numbers, comma-separated")
    var serials: String?
    @Option(name: .customLong("csv-file"), help: "Path to CSV file containing serial numbers (first column)")
    var csvFile: String?
    @Flag(name: .customLong("mdm"), help: "Only output assigned MDM server info")
    var mdmOnly: Bool = false
    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?
    func validate() throws {
        guard (serials != nil) != (csvFile != nil) else {
            throw ValidationError("Must specify either --serials or --csv-file, but not both")
        }
    }
    func run() async throws {
        var cmd = GetDevicesInfo()
        cmd.serials = serials
        cmd.csvFile = csvFile
        cmd.mdmOnly = mdmOnly
        cmd.profileName = profileName
        try await cmd.run()
    }
}

struct GetDeviceAlias: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get-device",
        abstract: "Alias for get-devices-info",
        shouldDisplay: false
    )
    @Option(name: .customLong("serials"), help: "One or more serial numbers, comma-separated")
    var serials: String?
    @Option(name: .customLong("csv-file"), help: "Path to CSV file containing serial numbers (first column)")
    var csvFile: String?
    @Flag(name: .customLong("mdm"), help: "Only output assigned MDM server info")
    var mdmOnly: Bool = false
    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?
    func validate() throws {
        guard (serials != nil) != (csvFile != nil) else {
            throw ValidationError("Must specify either --serials or --csv-file, but not both")
        }
    }
    func run() async throws {
        var cmd = GetDevicesInfo()
        cmd.serials = serials
        cmd.csvFile = csvFile
        cmd.mdmOnly = mdmOnly
        cmd.profileName = profileName
        try await cmd.run()
    }
}
