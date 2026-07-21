import AppKit
import SwiftUI
import ShelfUI

/// Renders a collection into a single shareable image: its previews in the same
/// masonry the app draws, at fixed export width, saved wherever the user picks.
@MainActor
enum MoodboardExporter {

    /// Kept modest so a large collection still renders quickly and the output
    /// stays a sane size for sharing.
    private static let assetLimit = 60
    private static let exportWidth: CGFloat = 1240

    static func export(_ category: ShelfCategory) async {
        // Gather decoded previews first, so the render itself is synchronous.
        var previews: [(image: NSImage, ratio: CGFloat)] = []
        for asset in category.assets.sorted(by: { $0.addedAt > $1.addedAt }).prefix(assetLimit) {
            guard let decoded = await ThumbnailStore.thumbnail(
                id: asset.id, revision: asset.thumbnailRevision, bookmark: asset.bookmark
            ) else { continue }
            previews.append((decoded.image, decoded.aspectRatio ?? 1))
        }
        guard !previews.isEmpty else { return }

        let board = BoardView(
            title: category.name,
            palette: category.palette(),
            previews: previews
        )
        .frame(width: exportWidth)

        let renderer = ImageRenderer(content: board)
        renderer.scale = 2
        guard let rendered = renderer.nsImage,
              let tiff = rendered.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(category.name) Moodboard.png"

        guard panel.runModal() == .OK, let destination = panel.url else { return }
        try? png.write(to: destination)
        NSWorkspace.shared.activateFileViewerSelecting([destination])
    }

    /// The board itself: quiet title, then the masonry. Light appearance always,
    /// since the export is a document rather than a window.
    private struct BoardView: View {
        let title: String
        let palette: [String]
        let previews: [(image: NSImage, ratio: CGFloat)]

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(.sRGB, white: 0.15, opacity: 1))

                if !palette.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: 2) {
                            ForEach(palette, id: \.self) { hex in
                                Rectangle().fill(Color(hex: hex) ?? .clear)
                            }
                        }
                        .frame(height: 36)
                        .clipShape(RoundedRectangle.shelf(Radius.small))

                        HStack(spacing: 2) {
                            ForEach(palette, id: \.self) { hex in
                                Text(hex)
                                    .font(.system(size: 9).monospaced())
                                    .foregroundStyle(Color(.sRGB, white: 0.45, opacity: 1))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }

                MasonryLayout(columnWidth: 280, spacing: Spacing.l) {
                    ForEach(Array(previews.enumerated()), id: \.offset) { _, preview in
                        Image(nsImage: preview.image)
                            .resizable()
                            .aspectRatio(preview.ratio, contentMode: .fit)
                            .clipShape(RoundedRectangle.shelf(Radius.medium))
                    }
                }
            }
            .padding(Spacing.xl)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        }
    }
}
