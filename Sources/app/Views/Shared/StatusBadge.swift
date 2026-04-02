import SwiftUI

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch status.uppercased() {
        case "ASSIGNED", "COMPLETE", "COMPLETED", "ACTIVE", "CONNECTED":
            return .green
        case "UNASSIGNED", "PENDING", "IN_PROGRESS":
            return .orange
        case "FAILED", "ERROR", "EXPIRED", "CANCELED":
            return .red
        case "TIMEOUT":
            return .purple
        default:
            return .gray
        }
    }
}
