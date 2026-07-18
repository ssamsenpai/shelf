import SwiftUI

/// Preview first grid tile. The thumbnail fills the tile, the name sits below in one
/// line, and the kind stays quiet until hover.
public struct AssetTile: View {
    private let name: String
    private let kindTitle: String
    private let symbol: String
    private let thumbnail: Image?
    private let isSelected: Bool

    @State private var hovering = false

    public init(
        name: String,
        kindTitle: String,
        symbol: String,
        thumbnail: Image?,
        isSelected: Bool = false
    ) {
        self.name = name
        self.kindTitle = kindTitle
        self.symbol = symbol
        self.thumbnail = thumbnail
        self.isSelected = isSelected
    }

    public var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                RoundedRectangle.shelf(Radius.medium)
                    .fill(Color.shelfWell)

                if let thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(Spacing.xs)
                } else {
                    // Type badge placeholder. Never a broken image glyph.
                    TypeBadge(symbol: symbol, kindTitle: kindTitle)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle.shelf(Radius.medium))
            .overlay {
                RoundedRectangle.shelf(Radius.medium)
                    .strokeBorder(Color.shelfAccent, lineWidth: isSelected ? 2.5 : 0)
            }
            .scaleEffect(hovering ? 1.02 : 1)
            .shelfShadow(lifted: hovering)

            VStack(spacing: 1) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(kindTitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .opacity(hovering ? 1 : 0)
            }
        }
        .padding(Spacing.xs)
        .background(
            isSelected ? Color.shelfAccent.opacity(0.12) : .clear,
            in: .shelf(Radius.medium)
        )
        .onHover { hovering = $0 }
        .shelfAnimation(Motion.smooth, value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(kindTitle)")
    }
}

/// Clean placeholder for files the system cannot preview.
public struct TypeBadge: View {
    private let symbol: String
    private let kindTitle: String

    public init(symbol: String, kindTitle: String) {
        self.symbol = symbol
        self.kindTitle = kindTitle
    }

    public var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text(kindTitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
