import ArgumentParser

@main
struct ASBMUtil: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "asbmutil",
        abstract: "Apple School & Business Manager CLI \(AppVersion.version)",
        version: AppVersion.version,
        subcommands: [
            Config.self,
            ListDevices.self,
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
