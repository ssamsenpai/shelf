import AppKit
import SwiftUI
import ShelfUI

/// The collection's palette as one continuous full width bar, segments sized
/// equally, most common color first. Hovering a segment reveals its hex on the
/// color itself, clicking copies it.
///
/// Hover feedback is opacity only, on views that are always present: nothing is
/// inserted, removed, or resized on hover, so the bar never shifts and never
/// animates layout while the pointer moves across it.
struct CollectionPalette: View {
    let category: ShelfCategory

    @State private var copiedHex: String?
    @State private var hoveredHex: String?

    var body: some View {
        let colors = category.palette()

        if !colors.isEmpty {
            HStack(spacing: 2) {
                ForEach(colors, id: \.self) { hex in
                    segment(hex)
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle.shelf(Radius.medium))
            .onHover { inside in
                if !inside { hoveredHex = nil }
            }
            // One reset task for the whole bar, not one per segment.
            .task(id: copiedHex) {
                guard copiedHex != nil else { return }
                try? await Task.sleep(for: .seconds(2))
                copiedHex = nil
            }
        }
    }

    private func segment(_ hex: String) -> some View {
        let isHovered = hoveredHex == hex
        let showsCopied = copiedHex == hex

        return Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(hex, forType: .string)
            copiedHex = hex
        } label: {
            Rectangle()
                .fill(Color(hex: hex) ?? .clear)
                .overlay {
                    // Both labels exist permanently. Only their opacity moves.
                    ZStack {
                        Text(hex)
                            .opacity(isHovered && !showsCopied ? 1 : 0)
                        Label("Copied", systemImage: "checkmark")
                            .opacity(showsCopied ? 1 : 0)
                    }
                    .font(.caption2.monospaced().weight(.medium))
                    .foregroundStyle(idealTextColor(for: hex))
                    .lineLimit(1)
                    .fixedSize()
                    .animation(Motion.crossFade, value: isHovered)
                    .animation(Motion.crossFade, value: showsCopied)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            // Only ever set, never clear, per segment: clearing happens when the
            // pointer leaves the whole bar. Crossing the gaps between segments
            // therefore cannot flicker.
            if inside, hoveredHex != hex { hoveredHex = hex }
        }
        .help("Copy \(hex)")
    }

    /// Black or white, whichever survives on the swatch.
    private func idealTextColor(for hex: String) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard let value = UInt32(cleaned, radix: 16) else { return .white }

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.55 ? .black : .white
    }
}
