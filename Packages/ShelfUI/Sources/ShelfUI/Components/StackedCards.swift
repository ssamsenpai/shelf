import SwiftUI

/// A category drawn as a small fanned stack of cards, showing what is actually
/// inside it. Three cards at most: two behind, one in front.
///
/// This is the signature component, so it earns the one soft shadow token. On hover
/// the fan opens and the stack lifts, which is the whole affordance: it should feel
/// like something you could pick up.
public struct StackedCards: View {
    private let name: String
    private let count: Int
    /// Front card first. Missing or still loading previews render as blank cards.
    private let previews: [Image?]
    private let isSelected: Bool
    private let isDropTarget: Bool
    private let placeholderSymbol: String

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        name: String,
        count: Int,
        previews: [Image?],
        isSelected: Bool = false,
        isDropTarget: Bool = false,
        placeholderSymbol: String = "square.stack"
    ) {
        self.name = name
        self.count = count
        self.previews = previews
        self.isSelected = isSelected
        self.isDropTarget = isDropTarget
        self.placeholderSymbol = placeholderSymbol
    }

    private var isActive: Bool { hovering || isDropTarget }

    /// How far the two back cards swing out. Visible at rest so the stack reads
    /// as one, opening further on hover. Reduce Motion keeps them at rest.
    private var fan: Double {
        guard !reduceMotion else { return 10 }
        return isActive ? 16 : 10
    }

    private var spread: CGFloat {
        guard !reduceMotion else { return 15 }
        return isActive ? 22 : 15
    }

    /// The back cards also peek above the front one, like a loose pile.
    private var peek: CGFloat { spread * 0.55 }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            stack
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(reduceMotion ? 1 : (isActive ? 1.03 : 1))

            VStack(spacing: 2) {
                Text(name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(countLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .onHover { hovering = $0 }
        .shelfAnimation(Motion.smooth, value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(countLabel)")
    }

    private var countLabel: String {
        count == 1 ? "1 item" : "\(count) items"
    }

    private var stack: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height) * 0.80

            ZStack {
                card(preview: preview(at: 2), side: side)
                    .scaleEffect(0.96)
                    .rotationEffect(.degrees(fan))
                    .offset(x: spread, y: -peek)

                card(preview: preview(at: 1), side: side)
                    .scaleEffect(0.96)
                    .rotationEffect(.degrees(-fan))
                    .offset(x: -spread, y: -peek)

                card(preview: preview(at: 0), side: side)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// Back cards are only drawn when there is enough in the category to suggest
    /// depth, so a single item does not pretend to be a stack.
    private func preview(at index: Int) -> Image?? {
        // The front card always exists, so an empty category still reads as a card
        // rather than as nothing at all.
        guard index == 0 || count > index else { return nil }
        return previews.indices.contains(index) ? previews[index] : Image?.none
    }

    @ViewBuilder
    private func card(preview: Image??, side: CGFloat) -> some View {
        // Portrait cards with generous continuous corners, the iOS squircle feel.
        let width = side * 0.82
        let corner = width * 0.24
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        if let preview {
            shape
                .fill(Color.shelfContent)
                // Anchored to the top edge, so filling a portrait card crops the
                // bottom of the image and never the top.
                .overlay(alignment: .top) {
                    if let image = preview {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .overlay {
                    if preview == Image?.none {
                        // Solid enough to read as deliberate rather than as a
                        // card that failed to load.
                        Image(systemName: count == 0 ? "plus" : placeholderSymbol)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(borderColor, lineWidth: borderWidth)
                }
                .frame(width: width, height: side)
                .shelfShadow(lifted: true)
        }
    }

    private var borderColor: Color {
        if isDropTarget { return .shelfAccent }
        if isSelected { return .shelfAccent }
        return .clear
    }

    private var borderWidth: CGFloat {
        isDropTarget || isSelected ? 2 : 0
    }
}
