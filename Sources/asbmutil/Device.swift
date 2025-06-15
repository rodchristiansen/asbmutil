import Foundation

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
    let serialNumber: String                 // always present
    let model: String?                       // optional
    let partNumber: String?                  // optional
    let deviceManagementServiceId: String?   // optional
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

