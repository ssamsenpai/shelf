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

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        name: String,
        count: Int,
        previews: [Image?],
        isSelected: Bool = false,
        isDropTarget: Bool = false
    ) {
        self.name = name
        self.count = count
        self.previews = previews
        self.isSelected = isSelected
        self.isDropTarget = isDropTarget
    }

    private var isActive: Bool { hovering || isDropTarget }

    /// How far the two back cards swing out. Reduce Motion keeps them at rest.
    private var fan: Double {
        guard !reduceMotion else { return 7 }
        return isActive ? 13 : 7
    }

    private var spread: CGFloat {
        guard !reduceMotion else { return 10 }
        return isActive ? 17 : 10
    }

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
            let side = min(proxy.size.width, proxy.size.height) * 0.82

            ZStack {
                card(preview: preview(at: 2), side: side)
                    .rotationEffect(.degrees(fan))
                    .offset(x: spread)

                card(preview: preview(at: 1), side: side)
                    .rotationEffect(.degrees(-fan))
                    .offset(x: -spread)

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
        if let preview {
            RoundedRectangle.shelf(Radius.medium)
                // A blank white card reads as broken. Items without a preview get a
                // quiet fill and a glyph instead.
                .fill(preview == nil ? Color.shelfWell : Color.shelfContent)
                .overlay {
                    if let image = preview {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: count == 0 ? "plus" : "square.stack")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipShape(RoundedRectangle.shelf(Radius.medium))
                .overlay {
                    RoundedRectangle.shelf(Radius.medium)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }
                .frame(width: side, height: side)
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
