import SwiftUI

/// How full a category is. Drives what peeks above the front flap.
public enum FolderFill: Equatable, Sendable {
    case empty
    case filling
    case filled

    public init(count: Int) {
        switch count {
        case 0: self = .empty
        case 1...3: self = .filling
        default: self = .filled
        }
    }
}

/// The signature component. Drawn entirely with shapes, no image assets.
/// Back tab, body, peeking contents, front flap, layered to read as a folder.
public struct FolderView: View {
    private let name: String
    private let count: Int
    private let isSelected: Bool
    private let isDropTarget: Bool

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(name: String, count: Int, isSelected: Bool = false, isDropTarget: Bool = false) {
        self.name = name
        self.count = count
        self.isSelected = isSelected
        self.isDropTarget = isDropTarget
    }

    private var fill: FolderFill { FolderFill(count: count) }

    /// The flap opens on hover and opens further when something is dragged over.
    private var flapAngle: Double {
        if reduceMotion { return 0 }
        if isDropTarget { return 26 }
        if hovering { return 10 }
        return 0
    }

    private var lift: CGFloat {
        guard !reduceMotion else { return 1 }
        return hovering || isDropTarget ? 1.02 : 1
    }

    private var bodyTint: Color {
        switch fill {
        case .empty: Color.shelfWell
        case .filling, .filled: Color.shelfAccent.opacity(0.22)
        }
    }

    private var flapTint: Color {
        isDropTarget ? Color.shelfAccent.opacity(0.55) : Color.shelfAccent.opacity(0.38)
    }

    public var body: some View {
        VStack(spacing: Spacing.s) {
            folder
                .aspectRatio(1.28, contentMode: .fit)
                .scaleEffect(lift)
                .shelfShadow(lifted: hovering || isDropTarget)
                .shelfAnimation(Motion.smooth, value: hovering)
                .shelfAnimation(Motion.smooth, value: isDropTarget)

            Text(name)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(count) items")
    }

    private var folder: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let flapHeight = size.height * 0.74

            ZStack(alignment: .bottom) {
                // Back panel with the tab.
                FolderBackShape(cornerRadius: Radius.folder)
                    .fill(bodyTint)

                // Contents peeking above the flap.
                peekingContents(in: size, flapHeight: flapHeight)

                // Front flap, hinged at the bottom edge.
                RoundedRectangle.shelf(Radius.folder)
                    .fill(flapTint)
                    .frame(height: flapHeight)
                    .rotation3DEffect(
                        .degrees(flapAngle),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.45
                    )

                if fill == .empty {
                    emptyHint
                }
            }
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    CountBadge(count: count)
                        .padding(Spacing.s)
                }
            }
            .overlay {
                // Selection is the only border here, because it carries meaning.
                RoundedRectangle.shelf(Radius.folder)
                    .strokeBorder(Color.shelfAccent, lineWidth: isSelected ? 2 : 0)
            }
        }
    }

    /// One or two corners for a filling category, a small fan once it is full.
    @ViewBuilder
    private func peekingContents(in size: CGSize, flapHeight: CGFloat) -> some View {
        let sheetWidth = size.width * 0.62
        let sheetHeight = size.height * 0.58

        ZStack {
            switch fill {
            case .empty:
                EmptyView()
            case .filling:
                sheet(width: sheetWidth, height: sheetHeight)
                    .offset(y: -flapHeight * 0.42)
            case .filled:
                sheet(width: sheetWidth * 0.92, height: sheetHeight)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -size.width * 0.08, y: -flapHeight * 0.40)
                sheet(width: sheetWidth * 0.92, height: sheetHeight)
                    .rotationEffect(.degrees(6))
                    .offset(x: size.width * 0.08, y: -flapHeight * 0.38)
                sheet(width: sheetWidth, height: sheetHeight)
                    .offset(y: -flapHeight * 0.46)
            }
        }
    }

    private func sheet(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle.shelf(Radius.small)
            .fill(Color.shelfContent)
            .frame(width: width, height: height)
    }

    private var emptyHint: some View {
        Image(systemName: "plus")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.bottom, Spacing.l)
    }
}

/// The classic tabbed folder back: a tab on the upper left, then a step down to the
/// full width body.
private struct FolderBackShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let tabWidth = rect.width * 0.42
        let tabHeight = rect.height * 0.16
        let stepWidth = rect.height * 0.10

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + tabHeight + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY + tabHeight),
            control: CGPoint(x: rect.minX, y: rect.minY + tabHeight)
        )
        path.addLine(to: CGPoint(x: rect.minX + tabWidth, y: rect.minY + tabHeight))
        // Angled step from the tab up to the body edge.
        path.addLine(to: CGPoint(x: rect.minX + tabWidth + stepWidth, y: rect.minY + tabHeight * 0.15))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

/// Item count. Rounded numerals, the one place a non default face appears.
public struct CountBadge: View {
    private let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        Text("\(count)")
            .font(.shelfNumeric(11))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 2)
            .background(Color.shelfAccent, in: .capsule)
    }
}
