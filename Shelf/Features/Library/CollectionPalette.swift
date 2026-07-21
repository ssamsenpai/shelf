import AppKit
import SwiftUI
import ShelfUI

/// The collection's own palette: dominant colors merged across everything in it,
/// most common first. Clicking a swatch copies its hex.
struct CollectionPalette: View {
    let category: ShelfCategory

    @State private var copiedHex: String?
    @State private var hoveredHex: String?

    /// Colors are already coarse from extraction, so identical hexes across
    /// assets really are the same bucket. Frequency decides the order.
    private var palette: [String] {
        var counts: [String: Int] = [:]
        for asset in category.assets {
            for hex in asset.dominantColors {
                counts[hex, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(8).map(\.key)
    }

    var body: some View {
        let colors = palette

        if !colors.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    ForEach(colors, id: \.self) { hex in
                        swatch(hex)
                    }
                }

                Text(caption)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var caption: String {
        if let copiedHex { return "Copied \(copiedHex)" }
        if let hoveredHex { return hoveredHex }
        return "Collection palette. Click a color to copy it."
    }

    private func swatch(_ hex: String) -> some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(hex, forType: .string)

            copiedHex = hex
        } label: {
            RoundedRectangle.shelf(Radius.small)
                .fill(Color(hex: hex) ?? .clear)
                .frame(width: 44, height: 30)
                .overlay {
                    RoundedRectangle.shelf(Radius.small)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .onHover { hoveredHex = $0 ? hex : nil }
        .help("Copy \(hex)")
        .task(id: copiedHex) {
            guard copiedHex != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            copiedHex = nil
        }
    }
}
