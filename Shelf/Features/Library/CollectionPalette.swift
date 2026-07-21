import AppKit
import SwiftUI
import ShelfUI

/// The collection's palette as one continuous full width bar, segments sized
/// equally, most common color first. Hovering a segment reveals its hex on the
/// color itself, clicking copies it.
struct CollectionPalette: View {
    let category: ShelfCategory

    @State private var copiedHex: String?
    @State private var hoveredHex: String?

    var body: some View {
        let colors = category.palette()

        if !colors.isEmpty {
            HStack(spacing: 2) {
                ForEach(colors, id: \.self) { hex in
                    segment(hex, isFirst: hex == colors.first, isLast: hex == colors.last)
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle.shelf(Radius.medium))
            .shelfAnimation(Motion.snappy, value: hoveredHex)
        }
    }

    private func segment(_ hex: String, isFirst: Bool, isLast: Bool) -> some View {
        let color = Color(hex: hex) ?? .clear
        let isHovered = hoveredHex == hex
        let showsCopied = copiedHex == hex

        return Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(hex, forType: .string)
            copiedHex = hex
        } label: {
            Rectangle()
                .fill(color)
                .overlay {
                    if isHovered || showsCopied {
                        Label(
                            showsCopied ? "Copied" : hex,
                            systemImage: showsCopied ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption2.monospaced().weight(.medium))
                        .foregroundStyle(idealTextColor(for: hex))
                        .labelStyle(.titleAndIcon)
                        .transition(.opacity)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hoveredHex = $0 ? hex : nil }
        .help("Copy \(hex)")
        .task(id: copiedHex) {
            guard copiedHex != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            copiedHex = nil
        }
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
