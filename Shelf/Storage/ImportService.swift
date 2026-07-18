import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Everything known about a file at import time. Sendable so it can cross back to
/// the main actor, where the SwiftData model is created.
struct ImportedFile: Sendable {
    let name: String
    let kind: ItemKind
    let bookmark: Data
    let originalPath: String
    let fileSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int
    let createdAt: Date?
    let modifiedAt: Date?
    let dominantColors: [String]
}

/// Reads metadata and mints bookmarks. Runs off the main actor. Copies nothing.
enum ImportService {

    static func prepare(urls: [URL]) async -> [ImportedFile] {
        var results: [ImportedFile] = []
        for url in urls {
            if let file = prepare(url: url) {
                results.append(file)
            }
        }
        return results
    }

    private static func prepare(url: URL) -> ImportedFile? {
        guard !ImportExclusions.excludes(url) else { return nil }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let keys: Set<URLResourceKey> = [
            .contentTypeKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey
        ]
        let values = try? url.resourceValues(forKeys: keys)

        guard let type = values?.contentType, let kind = ItemKind.matching(type) else {
            return nil
        }
        guard let bookmark = try? BookmarkStore.makeBookmark(for: url) else {
            return nil
        }

        let dimensions = pixelDimensions(of: url)
        let colors = (kind == .image || kind == .svg) ? ColorExtractor.dominantColors(of: url) : []

        return ImportedFile(
            name: url.deletingPathExtension().lastPathComponent,
            kind: kind,
            bookmark: bookmark,
            originalPath: url.path(percentEncoded: false),
            fileSize: Int64(values?.fileSize ?? 0),
            pixelWidth: dimensions?.width ?? 0,
            pixelHeight: dimensions?.height ?? 0,
            createdAt: values?.creationDate,
            modifiedAt: values?.contentModificationDate,
            dominantColors: colors
        )
    }

    private static func pixelDimensions(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        guard let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }

        return (width, height)
    }
}

/// Pulls a small palette out of an image by downsampling and bucketing.
enum ColorExtractor {

    static func dominantColors(of url: URL, limit: Int = 5) -> [String] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 48
              ] as CFDictionary)
        else { return [] }

        return dominantColors(in: image, limit: limit)
    }

    private static func dominantColors(in image: CGImage, limit: Int) -> [String] {
        let width = 32
        let height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Bucket into a coarse grid so near identical shades collapse together.
        var counts: [Int: Int] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = pixels[index + 3]
            guard alpha > 128 else { continue }

            let r = Int(pixels[index]) / 32
            let g = Int(pixels[index + 1]) / 32
            let b = Int(pixels[index + 2]) / 32
            counts[(r << 10) | (g << 5) | b, default: 0] += 1
        }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { key, _ in
                let r = ((key >> 10) & 0x1F) * 32 + 16
                let g = ((key >> 5) & 0x1F) * 32 + 16
                let b = (key & 0x1F) * 32 + 16
                return String(format: "#%02X%02X%02X", min(r, 255), min(g, 255), min(b, 255))
            }
    }
}
