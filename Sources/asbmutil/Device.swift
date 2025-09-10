import Foundation

// Helper type to handle fields that can be either a string or an array of strings
enum StringOrArray: Codable, Sendable {
    case string(String)
    case array([String])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(StringOrArray.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }
    
    // Convenience properties
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .array(let values):
            return values.first
        }
    }
    
    var allValues: [String] {
        switch self {
        case .string(let value):
            return [value]
        case .array(let values):
            return values
        }
    }
}

struct OrgDevicesResponse: Decodable, Sendable {
    let data: [DeviceData]
    let meta: Meta?
}

struct Meta: Decodable, Sendable {
    let paging: Paging
}

struct Paging: Decodable, Sendable {
    let nextCursor: String?
}

struct DeviceData: Decodable, Sendable {
    let id: String
    let attributes: DeviceAttributes
}

struct DeviceAttributes: Decodable, Encodable, Sendable {
    // Core identifiers
    let serialNumber: String                 // always present
    
    // Device information
    let color: String?                       // The color of the device
    let deviceCapacity: String?              // The capacity of the device
    let deviceModel: String?                 // The model name (formerly 'model')
    let model: String?                       // Legacy field name for backward compatibility
    
    // Network identifiers - some may be arrays for devices with multiple values
    let eid: StringOrArray?                  // The device's EID (if available)
    let imei: StringOrArray?                 // The device's IMEI (if available) - can be array for dual SIM
    let meid: StringOrArray?                 // The device's MEID (if available)
    let wifiMacAddress: String?              // The device's Wi-Fi MAC address
    let bluetoothMacAddress: String?         // The device's Bluetooth MAC address
    
    // Order and purchase information
    let orderDateTime: String?               // The date and time of placing the device's order
    let orderNumber: String?                 // The order number of the device
    let partNumber: String?                  // The part number of the device
    let purchaseSourceType: String?          // The device's purchase source type: APPLE, RESELLER, or MANUALLY_ADDED
    let purchaseSourceId: String?            // The unique ID of the purchase source type: Apple Customer Number or Reseller Number
    
    // Product classification
    let productFamily: String?               // The device's Apple product family: iPhone, iPad, Mac, AppleTV, Watch, or Vision
    let productType: String?                 // The device's product type (examples: iPhone14,3, iPad13,4, MacBookPro14,2)
    
    // Status and timestamps
    let status: String?                      // The devices status: ASSIGNED or UNASSIGNED
    let addedToOrgDateTime: String?          // The date and time of adding the device to an organization
    let updatedDateTime: String?             // The date and time of the most-recent update for the device
    
    // Management
    let deviceManagementServiceId: String?   // optional - for assigned devices
}

struct MdmServersResponse: Decodable, Sendable {
    let data: [MdmServerData]
    let meta: Meta?
}

struct MdmServerData: Decodable, Sendable {
    let id: String
    let attributes: MdmServerAttributes
}

struct MdmServerAttributes: Decodable, Encodable, Sendable {
    let serverName: String?
    let serverType: String?
    let createdDateTime: String?
    let updatedDateTime: String?
    let devices: [String]?
}

struct MdmServerWithId: Decodable, Encodable, Sendable {
    let id: String
    let serverName: String?
    let serverType: String?
    let createdDateTime: String?
    let updatedDateTime: String?
}

