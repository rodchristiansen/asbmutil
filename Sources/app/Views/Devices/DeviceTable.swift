import SwiftUI
import ASBMUtilCore

private extension DeviceAttributes {
    var sortProductFamily: String { productFamily ?? "" }
    var sortProductType: String { productType ?? "" }
    var sortStatus: String { status ?? "" }
    var sortDeviceCapacity: String { deviceCapacity ?? "" }
    var sortPurchaseSourceType: String { purchaseSourceType ?? "" }
    var sortOrderNumber: String { orderNumber ?? "" }
    var sortOrderDateTime: String { orderDateTime ?? "" }
    var sortUpdatedDateTime: String { updatedDateTime ?? "" }
}

struct DeviceTable: View {
    let devices: [DeviceAttributes]
    @Binding var selection: Set<String>
    @State private var sortOrder: [KeyPathComparator<DeviceAttributes>] = [
        KeyPathComparator(\.serialNumber)
    ]

    private var sortedDevices: [DeviceAttributes] {
        devices.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedDevices, selection: $selection, sortOrder: $sortOrder) {
            group1
            group2
        }
    }

    @TableColumnBuilder<DeviceAttributes, KeyPathComparator<DeviceAttributes>>
    private var group1: some TableColumnContent<DeviceAttributes, KeyPathComparator<DeviceAttributes>> {
        TableColumn("Serial Number", value: \.serialNumber) { (d: DeviceAttributes) in
            Text(d.serialNumber).fontDesign(.monospaced)
        }
        .width(min: 110, ideal: 140)

        TableColumn("Model", value: \.displayModel) { (d: DeviceAttributes) in
            Text(d.displayModel)
        }
        .width(min: 120, ideal: 180)

        TableColumn("Product Family", value: \.sortProductFamily) { (d: DeviceAttributes) in
            Text(d.productFamily ?? "")
        }
        .width(min: 80, ideal: 110)

        TableColumn("Product Type", value: \.sortProductType) { (d: DeviceAttributes) in
            Text(d.productType ?? "")
        }
        .width(min: 90, ideal: 120)

        TableColumn("Status", value: \.sortStatus) { (d: DeviceAttributes) in
            StatusBadge(status: d.status ?? "")
        }
        .width(min: 80, ideal: 100)
    }

    @TableColumnBuilder<DeviceAttributes, KeyPathComparator<DeviceAttributes>>
    private var group2: some TableColumnContent<DeviceAttributes, KeyPathComparator<DeviceAttributes>> {
        TableColumn("Storage", value: \.sortDeviceCapacity) { (d: DeviceAttributes) in
            Text(d.deviceCapacity ?? "")
        }
        .width(min: 60, ideal: 80)

        TableColumn("Source", value: \.sortPurchaseSourceType) { (d: DeviceAttributes) in
            Text(d.purchaseSourceType ?? "")
        }
        .width(min: 60, ideal: 100)

        TableColumn("Order Number", value: \.sortOrderNumber) { (d: DeviceAttributes) in
            Text(d.orderNumber ?? "")
        }
        .width(min: 80, ideal: 130)

        TableColumn("Order Date", value: \.sortOrderDateTime) { (d: DeviceAttributes) in
            Text(d.orderDateTime ?? "")
        }
        .width(min: 80, ideal: 120)

        TableColumn("Updated", value: \.sortUpdatedDateTime) { (d: DeviceAttributes) in
            Text(d.updatedDateTime ?? "")
        }
        .width(min: 80, ideal: 120)
    }
}
