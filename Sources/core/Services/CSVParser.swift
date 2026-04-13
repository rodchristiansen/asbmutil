import Foundation

public enum CSVParser {
    /// Read serial numbers from a CSV file (first column of each row)
    public static func readSerials(from filePath: String) throws -> [String] {
        let url = URL(fileURLWithPath: filePath)
        return try readSerials(from: url)
    }

    /// Read serial numbers from a CSV file URL (first column of each row).
    /// Throws if the file produces no usable serials.
    public static func readSerials(from url: URL) throws -> [String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parseSerials(from: content)
    }

    /// Parse serial numbers from CSV content (first column of each row).
    /// Throws `RuntimeError` if no non-empty serials are found.
    public static func parseSerials(from content: String) throws -> [String] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var serials: [String] = []

        for line in lines {
            let columns = line.components(separatedBy: ",")
            if let firstColumn = columns.first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstColumn.isEmpty {
                serials.append(firstColumn)
            }
        }

        guard !serials.isEmpty else {
            throw RuntimeError("CSV contained no serial numbers (first column of each non-empty row).")
        }

        return serials
    }
}
