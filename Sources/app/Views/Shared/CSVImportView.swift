import SwiftUI
import ASBMUtilCore

struct CSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    let serials: [String]
    let onConfirm: ([String]) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("CSV Import Preview")
                .font(.headline)

            Text("\(serials.count) serial numbers found")
                .foregroundStyle(.secondary)

            List(serials, id: \.self) { serial in
                Text(serial)
                    .fontDesign(.monospaced)
            }
            .frame(minHeight: 200)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import") {
                    onConfirm(serials)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 300)
    }
}
