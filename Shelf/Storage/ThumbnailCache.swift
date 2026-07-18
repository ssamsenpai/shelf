import AppKit
import CoreGraphics
import ImageIO
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Disk backed thumbnail cache keyed by item id. Everything here runs off the main
/// actor and returns PNG `Data`, so no non sendable image type crosses a boundary.
///
/// The library renders from this cache, which is why it still looks complete when an
/// original has been moved or its volume is offline.
enum ThumbnailCache {

    static let pixelSize = CGSize(width: 512, height: 512)

    // MARK: Cache location

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Shelf/Thumbnails", directoryHint: .isDirectory)
    }

    private static func cacheURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).png", directoryHint: .notDirectory)
    }

    /// Cached PNG for an item, generating it from `bookmark` if this is the first ask.
    /// Returns nil when there is genuinely nothing to show.
    static func thumbnailData(id: UUID, bookmark: Data?) async -> Data? {
        let cached = cacheURL(for: id)
        if let data = try? Data(contentsOf: cached) {
            return data
        }

        guard let bookmark else { return nil }

        // Resolve and copy out what we need while access is held.
        let source: URL? = BookmarkStore.withResolvedURL(bookmark) { $0 } ?? nil
        guard let source else { return nil }

        let generated = await generate(for: source, bookmark: bookmark)
        if let generated {
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            try? generated.write(to: cached, options: .atomic)
        }
        return generated
    }

    static func removeCached(id: UUID) {
        try? FileManager.default.removeItem(at: cacheURL(for: id))
    }

    // MARK: Generation

    private static func generate(for url: URL, bookmark: Data) async -> Data? {
        if let data = await quickLookThumbnail(for: url, bookmark: bookmark) {
            return data
        }
        // Core Graphics fallback for anything QuickLook declines.
        return BookmarkStore.withResolvedURL(bookmark) { scoped in
            coreGraphicsThumbnail(for: scoped)
        } ?? nil
    }

    private static func quickLookThumbnail(for url: URL, bookmark: Data) async -> Data? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: pixelSize,
            scale: 2,
            representationTypes: .all
        )

        return await withCheckedContinuation { continuation in
            // Access has to be held for the duration of the generator's work.
            let resolved = BookmarkStore.resolveURL(bookmark)
            let scoped = resolved?.startAccessingSecurityScopedResource() ?? false

            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                let data = representation.flatMap { pngData(from: $0.cgImage) }
                if scoped { resolved?.stopAccessingSecurityScopedResource() }
                continuation.resume(returning: data)
            }
        }
    }

    private static func coreGraphicsThumbnail(for url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(pixelSize.width, pixelSize.height)
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return pngData(from: image)
    }

    private static func pngData(from image: CGImage?) -> Data? {
        guard let image else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
