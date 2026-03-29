import ArgumentParser
import Foundation

struct ListDevices: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-devices",
        abstract: "List all devices in this account"
    )

    @Option(name: .customLong("devices-per-page"), help: "Number of devices per API request (default: API default, typically 100)")
    var devicesPerPage: Int?
    
    @Option(name: .customLong("total-limit"), help: "Maximum total number of devices to retrieve (default: no limit)")
    var totalLimit: Int?
    
    @Flag(name: .customLong("show-pagination"), help: "Show detailed pagination information")
    var showPagination: Bool = false

    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?

    func validate() throws {
        if let devicesPerPage = devicesPerPage {
            guard devicesPerPage > 0 && devicesPerPage <= 1000 else {
                throw ValidationError("Devices per page must be between 1 and 1000")
            }
        }
        if let totalLimit = totalLimit {
            guard totalLimit > 0 else {
                throw ValidationError("Total limit must be greater than 0")
            }
        }
    }

    func run() async throws {
        let credentials = try Creds.load(profileName: profileName)
        let client = try await APIClient(credentials: credentials, profileName: profileName)
        
        if showPagination {
            FileHandle.standardError.write(Data("Starting device listing with pagination details...\n".utf8))
            if let totalLimit = totalLimit {
                FileHandle.standardError.write(Data("Total device limit: \(totalLimit)\n".utf8))
            }
            if let devicesPerPage = devicesPerPage {
                FileHandle.standardError.write(Data("Devices per page: \(devicesPerPage)\n".utf8))
            }
        }
        
        let devices = try await client.listDevices(devicesPerPage: devicesPerPage, totalLimit: totalLimit, showPagination: showPagination)
        print(String(decoding: try JSONEncoder().encode(devices), as: UTF8.self))
    }
}

struct Assign: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "assign",
        abstract: "Assign device serials to a management service"
    )
    @Option(name: .customLong("serials"), help: "Comma-separated list of device serial numbers")
    var serials: String?
    
    @Option(name: .customLong("csv-file"), help: "Path to CSV file containing serial numbers (first column)")
    var csvFile: String?
    
    @Option(name: .customLong("mdm"), help: "MDM server name")
    var mdmName: String

    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?
    
    func validate() throws {
        guard (serials != nil) != (csvFile != nil) else {
            throw ValidationError("Must specify either --serials or --csv-file, but not both")
        }
    }
    
    func run() async throws {
        let client = try await APIClient(credentials: Creds.load(profileName: profileName), profileName: profileName)
        let serviceId = try await client.getMdmServerIdByName(mdmName)
        
        let serialNumbers: [String]
        if let serials = serials {
            serialNumbers = serials
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else if let csvFile = csvFile {
            serialNumbers = try readSerialsFromCSV(filePath: csvFile)
        } else {
            throw ValidationError("No serial numbers provided")
        }
        
        let activityDetails = try await client.createDeviceActivity(
            activityType: "ASSIGN_DEVICES",
            serials: serialNumbers,
            serviceId: serviceId
        )
        print(String(decoding: try JSONEncoder().encode(activityDetails), as: UTF8.self))
    }
}

struct Unassign: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unassign",
        abstract: "Unassign device serials from a management service"
    )
    @Option(name: .customLong("serials"), help: "Comma-separated list of device serial numbers")
    var serials: String?
    
    @Option(name: .customLong("csv-file"), help: "Path to CSV file containing serial numbers (first column)")
    var csvFile: String?
    
    @Option(name: .customLong("mdm"), help: "MDM server name")
    var mdmName: String

    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?
    
    func validate() throws {
        guard (serials != nil) != (csvFile != nil) else {
            throw ValidationError("Must specify either --serials or --csv-file, but not both")
        }
    }
    
    func run() async throws {
        let client = try await APIClient(credentials: Creds.load(profileName: profileName), profileName: profileName)
        let serviceId = try await client.getMdmServerIdByName(mdmName)
        
        let serialNumbers: [String]
        if let serials = serials {
            serialNumbers = serials
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else if let csvFile = csvFile {
            serialNumbers = try readSerialsFromCSV(filePath: csvFile)
        } else {
            throw ValidationError("No serial numbers provided")
        }
        
        let activityDetails = try await client.createDeviceActivity(
            activityType: "UNASSIGN_DEVICES",
            serials: serialNumbers,
            serviceId: serviceId
        )
        print(String(decoding: try JSONEncoder().encode(activityDetails), as: UTF8.self))
    }
}

struct BatchStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "batch-status", 
        abstract: "Check status of a device activity operation"
    )
    @Argument var id: String

    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?

    func run() async throws {
        let client = try await APIClient(credentials: Creds.load(profileName: profileName), profileName: profileName)
        print(try await client.activityStatus(id: id))
    }
}

struct ListMdmServers: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-mdm-servers",
        abstract: "List all device management services"
    )

    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?

    func run() async throws {
        let credentials = try Creds.load(profileName: profileName)
        let client = try await APIClient(credentials: credentials, profileName: profileName)
        let servers = try await client.listMdmServers()
        print(String(decoding: try JSONEncoder().encode(servers), as: UTF8.self))
    }
}

// MARK: - List Device-Server Assignments

struct ListDevicesServers: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-devices-servers",
        abstract: "List device-to-server assignments"
    )

    // Server-side listing mode
    @Option(name: .customLong("mdm"), help: "List devices assigned to this MDM server name")
    var mdmName: String?

    @Option(name: .customLong("server-id"), help: "List devices assigned to this MDM server ID")
    var serverId: String?

    @Flag(name: .customLong("all"), help: "List devices for all MDM servers")
    var allServers: Bool = false

    // Device lookup mode
    @Option(name: .customLong("serials"), help: "Look up MDM assignments for these serial numbers (comma-separated)")
    var serials: String?

    @Option(name: .customLong("csv-file"), help: "Look up MDM assignments for serials in a CSV file (first column)")
    var csvFile: String?

    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?

    func validate() throws {
        let serverOptions = [mdmName != nil, serverId != nil, allServers]
        let deviceOptions = [serials != nil, csvFile != nil]
        let serverMode = serverOptions.filter({ $0 }).count
        let deviceMode = deviceOptions.filter({ $0 }).count

        if serverMode == 0 && deviceMode == 0 {
            throw ValidationError("Must specify a mode: --mdm, --server-id, --all, --serials, or --csv-file")
        }
        if serverMode > 0 && deviceMode > 0 {
            throw ValidationError("Cannot combine server listing (--mdm/--server-id/--all) with device lookup (--serials/--csv-file)")
        }
        if serverMode > 1 {
            throw ValidationError("Must specify only one of --mdm, --server-id, or --all")
        }
        if deviceMode > 1 {
            throw ValidationError("Must specify only one of --serials or --csv-file")
        }
    }

    func run() async throws {
        let client = try await APIClient(credentials: Creds.load(profileName: profileName), profileName: profileName)

        if serials != nil || csvFile != nil {
            try await runDeviceLookup(client: client)
        } else {
            try await runServerListing(client: client)
        }
    }

    // MARK: - Server listing: which devices are on a given server?

    private func runServerListing(client: APIClient) async throws {
        let servers = try await client.listMdmServers()

        struct ServerDeviceList: Encodable {
            let serverId: String
            let serverName: String?
            let serverType: String?
            let deviceCount: Int
            let devices: [String]
        }

        var results: [ServerDeviceList] = []

        if allServers {
            for server in servers {
                let serials = try await client.listMdmServerDevices(serverId: server.id)
                results.append(ServerDeviceList(
                    serverId: server.id,
                    serverName: server.serverName,
                    serverType: server.serverType,
                    deviceCount: serials.count,
                    devices: serials
                ))
                FileHandle.standardError.write(
                    Data("\(server.serverName ?? server.id): \(serials.count) devices\n".utf8)
                )
            }
        } else {
            let targetId: String
            if let serverId = serverId {
                targetId = serverId
            } else if let mdmName = mdmName {
                targetId = try await client.getMdmServerIdByName(mdmName)
            } else {
                throw RuntimeError("No server specified")
            }

            let server = servers.first { $0.id == targetId }
            let serials = try await client.listMdmServerDevices(serverId: targetId)
            results.append(ServerDeviceList(
                serverId: targetId,
                serverName: server?.serverName,
                serverType: server?.serverType,
                deviceCount: serials.count,
                devices: serials
            ))
            FileHandle.standardError.write(
                Data("\(server?.serverName ?? targetId): \(serials.count) devices\n".utf8)
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        print(String(decoding: try encoder.encode(results), as: UTF8.self))
    }

    // MARK: - Device lookup: which server is each serial on?

    private func runDeviceLookup(client: APIClient) async throws {
        let serialNumbers: [String]
        if let serials = serials {
            serialNumbers = serials.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else if let csvFile = csvFile {
            serialNumbers = try readSerialsFromCSV(filePath: csvFile)
        } else {
            throw ValidationError("No serial numbers provided")
        }

        let serialSet = Set(serialNumbers.map { $0.uppercased() })

        let servers = try await client.listMdmServers()
        FileHandle.standardError.write(Data("Fetched \(servers.count) MDM servers\n".utf8))

        var assignments: [String: AssignedMdmInfo] = [:]
        for server in servers {
            let deviceSerials = try await client.listMdmServerDevices(serverId: server.id)
            FileHandle.standardError.write(
                Data("  \(server.serverName ?? server.id): \(deviceSerials.count) devices\n".utf8)
            )
            for serial in deviceSerials {
                let upper = serial.uppercased()
                if serialSet.contains(upper) {
                    assignments[upper] = AssignedMdmInfo(
                        id: server.id,
                        serverName: server.serverName,
                        serverType: server.serverType
                    )
                }
            }
        }

        struct DeviceMdmResult: Encodable {
            let serialNumber: String
            let assignedMdm: AssignedMdmInfo?
        }

        let output = serialNumbers.map { serial in
            DeviceMdmResult(
                serialNumber: serial,
                assignedMdm: assignments[serial.uppercased()]
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        print(String(decoding: try encoder.encode(output), as: UTF8.self))

        let assigned = assignments.count
        let total = serialSet.count
        FileHandle.standardError.write(Data("Done: \(assigned)/\(total) devices have MDM assignments\n".utf8))
    }
}

struct GetAssignedMdm: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get-assigned-mdm",
        abstract: "Get the assigned device management service ID for a device",
        shouldDisplay: false
    )
    
    @Argument var deviceId: String

    @Option(name: .customLong("profile"), help: "Profile name to use for credentials")
    var profileName: String?
    
    func run() async throws {
        let client = try await APIClient(credentials: Creds.load(profileName: profileName), profileName: profileName)
        let assignedServer = try await client.getAssignedMdm(deviceId: deviceId)
        print(String(decoding: try JSONEncoder().encode(assignedServer), as: UTF8.self))
    }
}

// MARK: - Get Devices Info (includes AppleCare coverage and assigned MDM)

struct GetDevicesInfo: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get-devices-info",
        abstract: "Get full device information by serial number"
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
        let client = try await APIClient(credentials: Creds.load(profileName: profileName), profileName: profileName)
        
        let serialNumbers: [String]
        if let serials = serials {
            serialNumbers = serials.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else if let csvFile = csvFile {
            serialNumbers = try readSerialsFromCSV(filePath: csvFile)
        } else {
            throw ValidationError("No serial numbers provided")
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if serialNumbers.count == 1 {
            let device = try await client.getDevice(serialNumber: serialNumbers[0])
            if mdmOnly {
                print(String(decoding: try encoder.encode(device.assignedMdm), as: UTF8.self))
            } else {
                print(String(decoding: try encoder.encode(device), as: UTF8.self))
            }
        } else {
            var devices: [DeviceInfo] = []
            for serial in serialNumbers {
                do {
                    let device = try await client.getDevice(serialNumber: serial)
                    devices.append(device)
                } catch {
                    FileHandle.standardError.write(Data("Warning: Could not get device info for \(serial): \(error.localizedDescription)\n".utf8))
                }
                if serial != serialNumbers.last {
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            if mdmOnly {
                let mdmInfos = devices.map { $0.assignedMdm }
                print(String(decoding: try encoder.encode(mdmInfos), as: UTF8.self))
            } else {
                print(String(decoding: try encoder.encode(devices), as: UTF8.self))
            }
        }
    }
}

// Helper function to read serial numbers from CSV file
private func readSerialsFromCSV(filePath: String) throws -> [String] {
    let url = URL(fileURLWithPath: filePath)
    let content = try String(contentsOf: url, encoding: .utf8)
    
    let lines = content.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    
    var serials: [String] = []
    
    for line in lines {
        // Split by comma and take the first column (serial number)
        let columns = line.components(separatedBy: ",")
        if let firstColumn = columns.first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstColumn.isEmpty {
            serials.append(firstColumn)
        }
    }
    
    guard !serials.isEmpty else {
        throw ValidationError("No valid serial numbers found in CSV file: \(filePath)")
    }
    
    return serials
}
