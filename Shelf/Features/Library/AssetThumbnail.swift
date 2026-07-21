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
        .task(id: "\(asset.id)-\(asset.thumbnailRevision)") {
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

/// A loaded thumbnail plus its true pixel size.
///
/// The size matters because some kinds, PDFs above all, store no pixel dimensions
/// of their own. Measuring the rendered preview is the only reliable way to know
/// the real shape of the content.
struct LoadedThumbnail {
    let image: Image
    let pixelSize: CGSize
    /// True when the preview actually uses its alpha channel, checked on real
    /// pixels. Every cached thumbnail is PNG, so the format alone proves nothing.
    let hasTransparency: Bool

    var aspectRatio: CGFloat? {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        return pixelSize.width / pixelSize.height
    }
}

/// Samples a small render of the image and reports whether any pixel is
/// meaningfully transparent.
func detectTransparency(in nsImage: NSImage) -> Bool {
    let side = 32
    guard let context = CGContext(
        data: nil, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: side * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return false }

    context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
    guard let data = context.data else { return false }

    let pixels = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
    for index in stride(from: 3, to: side * side * 4, by: 4) where pixels[index] < 250 {
        return true
    }
    return false
}

/// A small holder that hands the loaded thumbnail to a builder, so tiles and rows
/// can share one loading path while drawing themselves differently.
struct ThumbnailProvider<Content: View>: View {
    let asset: Asset
    @ViewBuilder let content: (LoadedThumbnail?) -> Content

    @State private var loaded: LoadedThumbnail?

    var body: some View {
        content(loaded)
            .task(id: "\(asset.id)-\(asset.thumbnailRevision)") {
                let bookmark = asset.bookmark
                guard let data = await ThumbnailCache.thumbnailData(id: asset.id, bookmark: bookmark),
                      let nsImage = NSImage(data: data)
                else { return }

                // Pixel dimensions, not the point size NSImage reports.
                let pixels = nsImage.representations.first.map {
                    CGSize(width: $0.pixelsWide, height: $0.pixelsHigh)
                } ?? nsImage.size

                loaded = LoadedThumbnail(
                    image: Image(nsImage: nsImage),
                    pixelSize: pixels,
                    hasTransparency: detectTransparency(in: nsImage)
                )
            }
    }
}
