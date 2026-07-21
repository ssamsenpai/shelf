import SwiftUI

/// Equal width columns, dynamic heights: each subview keeps its own aspect and
/// drops into whichever column is currently shortest. The Pinterest layout.
public struct MasonryLayout: Layout {
    private let columnWidth: CGFloat
    private let spacing: CGFloat

    /// - Parameter columnWidth: Target width. The actual width flexes so the
    ///   columns always fill the container edge to edge.
    public init(columnWidth: CGFloat, spacing: CGFloat = Spacing.l) {
        self.columnWidth = columnWidth
        self.spacing = spacing
    }

    private func columnCount(for width: CGFloat) -> Int {
        max(2, Int((width + spacing) / (columnWidth + spacing)))
    }

    private struct Placement {
        var column: Int
        var y: CGFloat
        var height: CGFloat
    }

    private func solve(
        width: CGFloat, subviews: Subviews
    ) -> (placements: [Placement], columnWidth: CGFloat, height: CGFloat) {
        let count = columnCount(for: width)
        let colWidth = (width - CGFloat(count - 1) * spacing) / CGFloat(count)

        var heights = [CGFloat](repeating: 0, count: count)
        var placements: [Placement] = []
        placements.reserveCapacity(subviews.count)

        for subview in subviews {
            let height = subview.sizeThatFits(
                ProposedViewSize(width: colWidth, height: nil)
            ).height

            let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            let y = heights[column]
            placements.append(Placement(column: column, y: y, height: height))
            heights[column] = y + height + spacing
        }

        let total = (heights.max() ?? spacing) - spacing
        return (placements, colWidth, max(total, 0))
    }

    public func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? columnWidth * 2 + spacing
        let solved = solve(width: width, subviews: subviews)
        return CGSize(width: width, height: solved.height)
    }

    public func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let solved = solve(width: bounds.width, subviews: subviews)

        for (index, placement) in solved.placements.enumerated() {
            let x = bounds.minX + CGFloat(placement.column) * (solved.columnWidth + spacing)
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY + placement.y),
                proposal: ProposedViewSize(width: solved.columnWidth, height: placement.height)
            )
        }
    }
}

/// The classic transparency checkerboard, for previews of images that have an
/// alpha channel. Two quiet grays, identical in both appearances so transparency
/// always reads the same way.
public struct CheckerboardView: View {
    private let square: CGFloat

    public init(square: CGFloat = 8) {
        self.square = square
    }

    public var body: some View {
        Canvas { context, size in
            let light = Color(.sRGB, white: 0.93, opacity: 1)
            let dark = Color(.sRGB, white: 0.84, opacity: 1)

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(light))

            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row.isMultiple(of: 2) ? square : 0
                while x < size.width {
                    context.fill(
                        Path(CGRect(x: x, y: y, width: square, height: square)),
                        with: .color(dark)
                    )
                    x += square * 2
                }
                y += square
                row += 1
            }
        }
        .accessibilityHidden(true)
    }
}
