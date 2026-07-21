import SwiftUI

/// A neutral action button. Used where a control should read as secondary to the
/// content without looking disabled, so the label stays `.primary` and only the
/// fill carries the hierarchy.
///
/// This exists because the tinted system styles derive their label color from the
/// tint: graying the fill also grays the text.
public struct ShelfSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .padding(.horizontal, Spacing.m)
                .frame(height: 30)
                .background(fill, in: .shelf(Radius.small))
                .contentShape(RoundedRectangle.shelf(Radius.small))
                .onHover { hovering = $0 }
                .shelfAnimation(Motion.snappy, value: hovering)
        }

        private var fill: Color {
            guard isEnabled else { return .primary.opacity(0.05) }
            if configuration.isPressed { return .primary.opacity(0.22) }
            if hovering { return .primary.opacity(0.16) }
            return .primary.opacity(0.11)
        }
    }
}

/// The accent counterpart to `ShelfSecondaryButtonStyle`. Same height, padding, and
/// radius, so a primary and a secondary button sitting side by side match exactly.
public struct ShelfPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.m)
                .frame(height: 30)
                .background(ShelfGradient.primary, in: .shelf(Radius.small))
                .overlay {
                    // Hover lifts the gradient, a press settles it.
                    RoundedRectangle.shelf(Radius.small)
                        .fill(overlayTone)
                }
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(RoundedRectangle.shelf(Radius.small))
                .onHover { hovering = $0 }
                .shelfAnimation(Motion.snappy, value: hovering)
        }

        private var overlayTone: Color {
            if configuration.isPressed { return .black.opacity(0.14) }
            if hovering { return .white.opacity(0.14) }
            return .clear
        }
    }
}

public extension ButtonStyle where Self == ShelfSecondaryButtonStyle {
    /// Neutral fill, primary label, token radius.
    static var shelfSecondary: ShelfSecondaryButtonStyle { .init() }
}

public extension ButtonStyle where Self == ShelfPrimaryButtonStyle {
    /// Accent fill, white label, matching the secondary style's geometry.
    static var shelfPrimary: ShelfPrimaryButtonStyle { .init() }
}
