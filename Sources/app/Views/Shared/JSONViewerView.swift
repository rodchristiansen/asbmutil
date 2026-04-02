import SwiftUI

struct JSONViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let jsonString: String

    init(title: String, jsonString: String) {
        self.title = title
        self.jsonString = jsonString
    }

    init<T: Encodable>(title: String, encodable: T) {
        self.title = title
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(encodable),
           let string = String(data: data, encoding: .utf8) {
            self.jsonString = string
        } else {
            self.jsonString = "{ \"error\": \"Failed to encode\" }"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(jsonString, forType: .string)
                }
                Button("Close") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView([.horizontal, .vertical]) {
                Text(jsonString)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
