import SwiftUI
import ShelfUI

/// A loaded thumbnail plus what the views need to know about it.
///
/// The pixel size matters because some kinds, PDFs above all, store no dimensions
/// of their own: measuring the rendered preview is the only reliable way to know
/// the real shape of the content.
struct LoadedThumbnail {
    let image: Image
    let pixelSize: CGSize
    /// True when the preview actually uses its alpha channel, checked on pixels.
    let hasTransparency: Bool

    var aspectRatio: CGFloat? {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        return pixelSize.width / pixelSize.height
    }
}

/// Hands the loaded thumbnail to a builder, so tiles, rows, stacks, and the
/// inspector share one loading path while drawing themselves differently.
///
/// The work happens in ThumbnailStore off the main actor and lands in a memory
/// cache, so after the first appearance this resolves instantly.
struct ThumbnailProvider<Content: View>: View {
    let asset: Asset
    @ViewBuilder let content: (LoadedThumbnail?) -> Content

    @State private var loaded: LoadedThumbnail?

    var body: some View {
        content(loaded)
            .task(id: "\(asset.id)-\(asset.thumbnailRevision)") {
                let decoded = await ThumbnailStore.thumbnail(
                    id: asset.id,
                    revision: asset.thumbnailRevision,
                    bookmark: asset.bookmark
                )
                guard let decoded else { return }

                loaded = LoadedThumbnail(
                    image: Image(nsImage: decoded.image),
                    pixelSize: decoded.pixelSize,
                    hasTransparency: decoded.hasTransparency
                )
            }
    }
}
