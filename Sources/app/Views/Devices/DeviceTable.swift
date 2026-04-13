import SwiftUI
import ASBMUtilCore

struct DeviceTable: View {
    let devices: [DeviceAttributes]
    @Binding var selection: Set<String>

    var body: some View {
        Table(devices, selection: $selection) {
            group1
            group2
        }
    }

    @TableColumnBuilder<DeviceAttributes, Never>
    private var group1: some TableColumnContent<DeviceAttributes, Never> {
        TableColumn("Serial Number") { (d: DeviceAttributes) in
            Text(d.serialNumber).fontDesign(.monospaced)
        }
        .width(min: 110, ideal: 140)

        TableColumn("Model") { (d: DeviceAttributes) in
            Text(d.displayModel)
        }
        .width(min: 120, ideal: 180)

        TableColumn("Product Family") { (d: DeviceAttributes) in
            Text(d.productFamily ?? "")
        }
        .width(min: 80, ideal: 110)

        TableColumn("Product Type") { (d: DeviceAttributes) in
            Text(d.productType ?? "")
        }
        .width(min: 90, ideal: 120)

        TableColumn("Status") { (d: DeviceAttributes) in
            StatusBadge(status: d.status ?? "")
        }
        .width(min: 80, ideal: 100)
    }

    @TableColumnBuilder<DeviceAttributes, Never>
    private var group2: some TableColumnContent<DeviceAttributes, Never> {
        TableColumn("Storage") { (d: DeviceAttributes) in
            Text(d.deviceCapacity ?? "")
        }
        .width(min: 60, ideal: 80)

        TableColumn("Source") { (d: DeviceAttributes) in
            Text(d.purchaseSourceType ?? "")
        }
        .width(min: 60, ideal: 100)

        TableColumn("Order Number") { (d: DeviceAttributes) in
            Text(d.orderNumber ?? "")
        }
        .width(min: 80, ideal: 130)

        TableColumn("Order Date") { (d: DeviceAttributes) in
            Text(d.orderDateTime ?? "")
        }
        .width(min: 80, ideal: 120)

        TableColumn("Updated") { (d: DeviceAttributes) in
            Text(d.updatedDateTime ?? "")
        }
        .width(min: 80, ideal: 120)
    }
}
