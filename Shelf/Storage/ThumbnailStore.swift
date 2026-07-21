import AppKit
import Foundation
import ImageIO

/// A decoded, display ready preview. Immutable after creation, which is what makes
/// sharing the underlying image across isolation domains safe.
final class DecodedThumbnail: @unchecked Sendable {
    let image: NSImage
    let pixelSize: CGSize
    let hasTransparency: Bool

    init(image: NSImage, pixelSize: CGSize, hasTransparency: Bool) {
        self.image = image
        self.pixelSize = pixelSize
        self.hasTransparency = hasTransparency
    }

    var aspectRatio: CGFloat? {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        return pixelSize.width / pixelSize.height
    }
}

/// The memory layer over the disk cache. Each preview is decoded exactly once per
/// revision, downsampled to display scale, and served from memory afterwards, so
/// switching pages, switching views, and scrolling back never touch the disk or
/// the decoder again. Decoding runs off the main actor, so the UI never hitches
/// on it.
enum ThumbnailStore {

    // NSCache is documented thread safe and the stored object is immutable.
    nonisolated(unsafe) private static let cache: NSCache<NSString, DecodedThumbnail> = {
        let cache = NSCache<NSString, DecodedThumbnail>()
        cache.totalCostLimit = 192 * 1024 * 1024
        return cache
    }()

    /// Largest pixel edge kept in memory. Tiles and the inspector both render well
    /// below this. The disk cache keeps the full resolution for anything that
    /// later needs it.
    private static let maxPixels: CGFloat = 640

    nonisolated static func thumbnail(
        id: UUID, revision: Int, bookmark: Data?
    ) async -> DecodedThumbnail? {
        let key = "\(id.uuidString)-\(revision)" as NSString
        if let hit = cache.object(forKey: key) { return hit }

        guard let data = await ThumbnailCache.thumbnailData(id: id, bookmark: bookmark),
              let decoded = decode(data)
        else { return nil }

        let cost = Int(decoded.pixelSize.width * decoded.pixelSize.height) * 4
        cache.setObject(decoded, forKey: key, cost: cost)
        return decoded
    }

    /// Downsampled decode: the image comes out of ImageIO already at display
    /// scale, so nothing pays for drawing a 1024 pixel bitmap into a 200 point
    /// tile frame after frame.
    private nonisolated static func decode(_ data: Data) -> DecodedThumbnail? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let size = CGSize(width: cg.width, height: cg.height)
        return DecodedThumbnail(
            image: NSImage(cgImage: cg, size: size),
            pixelSize: size,
            hasTransparency: usesAlpha(cg)
        )
    }

    /// Samples a small render and reports whether any pixel is meaningfully
    /// transparent. Every cached thumbnail is PNG, so the format proves nothing.
    private nonisolated static func usesAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            break
        }

        let side = 32
        guard let context = CGContext(
            data: nil, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = context.data else { return false }

        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        for index in stride(from: 3, to: side * side * 4, by: 4) where pixels[index] < 250 {
            return true
        }
        return false
    }
}
