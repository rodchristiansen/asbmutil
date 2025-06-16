import ArgumentParser
import Foundation

struct ListDevices: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-devices",
        abstract: "List all organization devices"
    )

    @Option(name: .customLong("limit"), help: "Number of devices per page (default: API default, typically 100)")
    var limit: Int?
    
    @Flag(name: .customLong("show-pagination"), help: "Show detailed pagination information")
    var showPagination: Bool = false

    func validate() throws {
        if let limit = limit {
            guard limit > 0 && limit <= 1000 else {
                throw ValidationError("Limit must be between 1 and 1000")
            }
        }
    }

    func run() async throws {
        let credentials = try Creds.load()
        let client = try await APIClient(credentials: credentials)
        
        if showPagination {
            FileHandle.standardError.write(Data("Starting device listing with pagination details...\n".utf8))
        }
        
        let devices = try await client.listDevices(limit: limit)
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
    
    func validate() throws {
        guard (serials != nil) != (csvFile != nil) else {
            throw ValidationError("Must specify either --serials or --csv-file, but not both")
        }
    }
    
    func run() async throws {
        let client = try await APIClient(credentials: Creds.load())
        let serviceId = try await client.getMdmServerIdByName(mdmName)
        
        let serialNumbers: [String]
        if let serials = serials {
            serialNumbers = serials.split(separator: ",").map(String.init)
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
    
    func validate() throws {
        guard (serials != nil) != (csvFile != nil) else {
            throw ValidationError("Must specify either --serials or --csv-file, but not both")
        }
    }
    
    func run() async throws {
        let client = try await APIClient(credentials: Creds.load())
        let serviceId = try await client.getMdmServerIdByName(mdmName)
        
        let serialNumbers: [String]
        if let serials = serials {
            serialNumbers = serials.split(separator: ",").map(String.init)
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

    func run() async throws {
        let client = try await APIClient(credentials: Creds.load())
        print(try await client.activityStatus(id: id))
    }
}

struct ListMdmServers: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-mdm-servers",
        abstract: "List all device management services in the organization"
    )

    func run() async throws {
        let credentials = try Creds.load()
        let client = try await APIClient(credentials: credentials)
        let servers = try await client.listMdmServers()
        print(String(decoding: try JSONEncoder().encode(servers), as: UTF8.self))
    }
}

struct GetAssignedMdm: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get-assigned-mdm",
        abstract: "Get the assigned device management service ID for a device"
    )
    
    @Argument var deviceId: String
    
    func run() async throws {
        let client = try await APIClient(credentials: Creds.load())
        let assignedServer = try await client.getAssignedMdm(deviceId: deviceId)
        print(String(decoding: try JSONEncoder().encode(assignedServer), as: UTF8.self))
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