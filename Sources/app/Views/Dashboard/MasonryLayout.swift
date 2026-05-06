import SwiftUI

/// Pinterest-style layout: columns are computed from available width, each
/// child is placed into the currently-shortest column. Eliminates the row-aligned
/// gaps that LazyVGrid produces when cards have different heights.
struct MasonryLayout: Layout {
    var columnSpacing: CGFloat = 16
    var rowSpacing: CGFloat = 16
    var minColumnWidth: CGFloat = 360

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? minColumnWidth
        let metrics = layoutMetrics(forWidth: width, subviews: subviews)
        return CGSize(width: width, height: metrics.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let metrics = layoutMetrics(forWidth: bounds.width, subviews: subviews)
        for (index, frame) in metrics.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    struct Cache {}

    private struct Metrics {
        let frames: [CGRect]
        let totalHeight: CGFloat
    }

    private func layoutMetrics(forWidth width: CGFloat, subviews: Subviews) -> Metrics {
        let columnCount = max(1, Int((width + columnSpacing) / (minColumnWidth + columnSpacing)))
        let columnWidth = (width - CGFloat(columnCount - 1) * columnSpacing) / CGFloat(columnCount)
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for sv in subviews {
            let size = sv.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let col = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) ?? 0
            let x = CGFloat(col) * (columnWidth + columnSpacing)
            let y = columnHeights[col]
            frames.append(CGRect(x: x, y: y, width: columnWidth, height: size.height))
            columnHeights[col] += size.height + rowSpacing
        }

        let total = (columnHeights.max() ?? 0) - rowSpacing
        return Metrics(frames: frames, totalHeight: max(0, total))
    }
}
