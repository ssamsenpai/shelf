import SwiftUI

/// Wraps subviews onto as many lines as they need. Used for tag chips.
public struct FlowLayout: Layout {
    private let spacing: CGFloat

    public init(spacing: CGFloat = Spacing.xs) {
        self.spacing = spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, availableWidth: width)

        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height + (total > 0 ? spacing : 0)
        }
        return CGSize(width: width == .infinity ? rows.map(\.width).max() ?? 0 : width,
                      height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = layout(subviews: subviews, availableWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                var size = subviews[index].sizeThatFits(.unspecified)
                size.width = min(size.width, bounds.width)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(subviews: Subviews, availableWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            // A single item wider than the container would otherwise overflow
            // instead of fitting, which shows up as clipping on narrow windows.
            size.width = min(size.width, availableWidth)

            let needed = current.width + size.width + (current.indices.isEmpty ? 0 : spacing)

            if needed > availableWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.indices.append(index)
            current.width += size.width + (current.indices.count > 1 ? spacing : 0)
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
