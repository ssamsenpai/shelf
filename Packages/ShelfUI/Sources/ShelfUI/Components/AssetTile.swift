import SwiftUI

/// Preview first grid tile. The thumbnail fills the tile, the name sits below in one
/// line, and the kind stays quiet until hover.
public struct AssetTile: View {
    private let name: String
    private let kindTitle: String
    private let symbol: String
    private let thumbnail: Image?
    private let isSelected: Bool
    private let onOpen: (() -> Void)?
    private let aspectRatio: CGFloat
    private let fillsTile: Bool

    @State private var hovering = false

    /// - Parameters:
    ///   - aspectRatio: Shape of the tile. 1 keeps the uniform square used by the
    ///     grid. Pass the asset's own ratio for a layout that varies with content.
    ///   - fillsTile: When true the preview covers the tile edge to edge rather than
    ///     sitting inset. Use it when `aspectRatio` already matches the preview, so
    ///     nothing is cropped.
    public init(
        name: String,
        kindTitle: String,
        symbol: String,
        thumbnail: Image?,
        isSelected: Bool = false,
        aspectRatio: CGFloat = 1,
        fillsTile: Bool = false,
        onOpen: (() -> Void)? = nil
    ) {
        self.name = name
        self.kindTitle = kindTitle
        self.symbol = symbol
        self.thumbnail = thumbnail
        self.isSelected = isSelected
        self.aspectRatio = aspectRatio
        self.fillsTile = fillsTile
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                RoundedRectangle.shelf(Radius.medium)
                    .fill(Color.shelfWell)

                if let thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: fillsTile ? .fill : .fit)
                        .padding(fillsTile ? 0 : Spacing.xs)
                } else {
                    // Type badge placeholder. Never a broken image glyph.
                    TypeBadge(symbol: symbol, kindTitle: kindTitle)
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle.shelf(Radius.medium))
            .overlay(alignment: .topTrailing) {
                if hovering, let onOpen {
                    OpenAffordance(action: onOpen)
                        .padding(Spacing.s)
                }
            }
            .overlay {
                RoundedRectangle.shelf(Radius.medium)
                    .strokeBorder(Color.shelfAccent, lineWidth: isSelected ? 2.5 : 0)
            }
            .scaleEffect(hovering ? 1.02 : 1)
            .shelfShadow(lifted: hovering)

            Text(name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
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

/// Hover affordance that opens the referenced file outside Shelf. A system material
/// rather than glass, since this sits on content.
private struct OpenAffordance: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
                .background(.regularMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .help("Open in Finder")
        .accessibilityLabel("Open in Finder")
        .transition(.opacity)
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
