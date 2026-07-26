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
        // The preview fades in when it lands instead of popping.
        .shelfAnimation(Motion.snappy, value: thumbnail == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(kindTitle)")
    }

    /// A tile never grows taller than this ratio allows, so one endless
    /// screenshot cannot swallow a whole column.
    private static let tallestRatio: CGFloat = 0.45

    @ViewBuilder
    private var preview: some View {
        if let thumbnail {
            if aspectRatio < Self.tallestRatio {
                // Very tall content: show the top at its true scale and crop
                // the rest, instead of squeezing the whole thing into the box.
                GeometryReader { geo in
                    thumbnail
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.width / max(aspectRatio, 0.01))
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                        .clipped()
                }
                .aspectRatio(Self.tallestRatio, contentMode: .fit)
                .background {
                    if showsTransparency {
                        CheckerboardView()
                    }
                }
            } else {
                // The bitmap's own ratio, so the preview can never distort.
                thumbnail
                    .resizable()
                    .scaledToFit()
                    .background {
                        if showsTransparency {
                            CheckerboardView()
                        }
                    }
            }
        } else {
            // No preview: a quiet well at a gentle ratio, never a broken glyph.
            RoundedRectangle.shelf(Radius.medium)
                .fill(Color.shelfWell)
                .aspectRatio(min(max(aspectRatio, Self.tallestRatio), 2.6), contentMode: .fit)
                .overlay {
                    TypeBadge(symbol: symbol, kindTitle: kindTitle)
                }
        }
    }
}
