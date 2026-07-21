import SwiftUI

/// A row of color swatches. Hex shows on hover, so the row stays quiet at rest.
public struct SwatchRow: View {
    private let hexes: [String]
    private let onSelect: ((String) -> Void)?

    @State private var hovered: String?

    public init(hexes: [String], onSelect: ((String) -> Void)? = nil) {
        self.hexes = hexes
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ForEach(hexes, id: \.self) { hex in
                    swatch(hex)
                }
            }

            Text(hovered ?? " ")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func swatch(_ hex: String) -> some View {
        let shape = RoundedRectangle.shelf(Radius.small)
            .fill(Color(hex: hex) ?? .clear)
            .frame(height: 28)

        if let onSelect {
            Button { onSelect(hex) } label: { shape.contentShape(.rect) }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? hex : nil }
                .help("Find items with this color")
        } else {
            shape.onHover { hovered = $0 ? hex : nil }
        }
    }
}

/// A removable label. Used only inside the inspector.
public struct TagChip: View {
    private let text: String
    private let onRemove: (() -> Void)?

    public init(text: String, onRemove: (() -> Void)? = nil) {
        self.text = text
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(text)
                .font(.caption)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(text)")
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, 3)
        .background(Color.shelfWell, in: .capsule)
    }
}

public extension Color {
    /// Builds a color from a hex string. Returns nil rather than guessing.
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }

        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
