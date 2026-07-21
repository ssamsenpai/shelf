import SwiftUI

/// A masonry cell: the preview at its own aspect ratio, full width of the column,
/// name below. No fixed frame, the layout gives it width and asks for height.
///
/// Transparent formats sit on the classic checkerboard instead of a gray well, so
/// a transparent PNG reads as what it is rather than as artwork on a slab.
public struct MasonryTile: View {
    private let name: String
    private let kindTitle: String
    private let symbol: String
    private let thumbnail: Image?
    private let aspectRatio: CGFloat
    private let showsTransparency: Bool
    private let isSelected: Bool
    private let onOpen: (() -> Void)?

    @State private var hovering = false

    public init(
        name: String,
        kindTitle: String,
        symbol: String,
        thumbnail: Image?,
        aspectRatio: CGFloat,
        showsTransparency: Bool = false,
        isSelected: Bool = false,
        onOpen: (() -> Void)? = nil
    ) {
        self.name = name
        self.kindTitle = kindTitle
        self.symbol = symbol
        self.thumbnail = thumbnail
        self.aspectRatio = aspectRatio
        self.showsTransparency = showsTransparency
        self.isSelected = isSelected
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            preview
                .clipShape(RoundedRectangle.shelf(Radius.medium))
                .overlay {
                    RoundedRectangle.shelf(Radius.medium)
                        .strokeBorder(Color.shelfAccent, lineWidth: isSelected ? 2.5 : 0)
                }
                .overlay(alignment: .topTrailing) {
                    if hovering, let onOpen {
                        Button(action: onOpen) {
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(width: 22, height: 22)
                                .background(.regularMaterial, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                        .padding(Spacing.s)
                    }
                }
                .scaleEffect(hovering ? 1.015 : 1)
                .shelfShadow(lifted: hovering)

            Text(name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 2)
        }
        .onHover { hovering = $0 }
        .shelfAnimation(Motion.smooth, value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(kindTitle)")
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnail {
            thumbnail
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .background {
                    if showsTransparency {
                        CheckerboardView()
                    }
                }
        } else {
            // No preview: a quiet well at a gentle ratio, never a broken glyph.
            RoundedRectangle.shelf(Radius.medium)
                .fill(Color.shelfWell)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay {
                    TypeBadge(symbol: symbol, kindTitle: kindTitle)
                }
        }
    }
}
