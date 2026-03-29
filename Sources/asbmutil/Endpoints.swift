import Foundation

enum Endpoints {
    static func base(for scope: String) -> URL {
        switch scope {
        case "business.api":
            return URL(string: "https://api-business.apple.com/")!
        case "school.api":
            return URL(string: "https://api-school.apple.com/")!
        default:
            fatalError("unknown scope")
        }
    }
    case orgDevice(String)              // v1 single device lookup by serial
    case orgDeviceActivities
    case orgDeviceActivity(String)
    case mdmServers
    case mdmServerDevices(String)        // v1 devices assigned to an MDM server
    case appleCare(String)               // API 1.3: AppleCare coverage for a device

    var path: String {
        switch self {
        case .orgDevice(let serial): return "/v1/orgDevices/\(serial)"
        case .orgDeviceActivities: return "/v1/orgDeviceActivities"
        case .orgDeviceActivity(let id): return "/v1/orgDeviceActivities/\(id)"
        case .mdmServers: return "/v1/mdmServers"
        case .mdmServerDevices(let id): return "/v1/mdmServers/\(id)/relationships/devices"
        case .appleCare(let deviceId): return "/v1/orgDevices/\(deviceId)/appleCareCoverage"
        }
    }
}
