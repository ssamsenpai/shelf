import SwiftUI
import ShelfUI

/// Loads a cached thumbnail without ever blocking the UI. Shows a quiet placeholder
/// until the image is ready, then swaps it in.
struct AssetThumbnail: View {
    let asset: Asset

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .task(id: asset.id) {
            await load()
        }
    }

    /// The loaded image, for callers that compose their own container.
    var loaded: Image? { image }

    private func load() async {
        let id = asset.id
        let bookmark = asset.bookmark
        guard let data = await ThumbnailCache.thumbnailData(id: id, bookmark: bookmark),
              let nsImage = NSImage(data: data)
        else { return }

        image = Image(nsImage: nsImage)
    }
}

/// A small holder that hands the loaded image to a builder, so tiles and rows can
/// share one loading path while drawing themselves differently.
struct ThumbnailProvider<Content: View>: View {
    let asset: Asset
    @ViewBuilder let content: (Image?) -> Content

    @State private var image: Image?

    var body: some View {
        content(image)
            .task(id: asset.id) {
                let bookmark = asset.bookmark
                guard let data = await ThumbnailCache.thumbnailData(id: asset.id, bookmark: bookmark),
                      let nsImage = NSImage(data: data)
                else { return }
                image = Image(nsImage: nsImage)
            }
    }
}
