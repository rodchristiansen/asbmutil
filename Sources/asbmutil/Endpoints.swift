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
    case devices
    case device(String)
    case orgDeviceActivities
    case orgDeviceActivity(String)
    case mdmServers
    case appleCare(String)  // API 1.3: AppleCare coverage for a device

    var path: String {
        switch self {
        case .devices: return "/devices"
        case .device(let id): return "/devices/\(id)"
        case .orgDeviceActivities: return "/v1/orgDeviceActivities"
        case .orgDeviceActivity(let id): return "/v1/orgDeviceActivities/\(id)"
        case .mdmServers: return "/v1/mdmServers"
        case .appleCare(let deviceId): return "/v1/orgDevices/\(deviceId)/appleCareCoverage"
        }
    }
}
