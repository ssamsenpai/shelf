import Foundation
import SwiftData

/// One piece of material in the library. The file itself is never copied: `bookmark`
/// is a security scoped reference to wherever the user keeps it.
@Model
final class Asset {
    #Index<Asset>([\.addedAt], [\.name])

    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = ItemKind.image.rawValue

    /// Security scoped bookmark. Nil only for content authored inside Shelf.
    var bookmark: Data?
    /// Last known path, shown when the original cannot be resolved.
    var originalPath: String = ""

    var fileSize: Int64 = 0
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0

    var addedAt: Date = Date()
    var contentCreatedAt: Date?
    var contentModifiedAt: Date?

    var note: String = ""
    var tags: [String] = []
    /// Dominant colors as hex, extracted at import for images and SVG.
    var dominantColors: [String] = []

    var category: ShelfCategory?

    init(
        name: String,
        kind: ItemKind,
        bookmark: Data?,
        originalPath: String,
        fileSize: Int64 = 0,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        contentCreatedAt: Date? = nil,
        contentModifiedAt: Date? = nil,
        dominantColors: [String] = [],
        category: ShelfCategory? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.bookmark = bookmark
        self.originalPath = originalPath
        self.fileSize = fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.addedAt = Date()
        self.contentCreatedAt = contentCreatedAt
        self.contentModifiedAt = contentModifiedAt
        self.category = category
        self.dominantColors = dominantColors
    }

    var kind: ItemKind {
        ItemKind(rawValue: kindRaw) ?? .image
    }

    /// Derived from the stored path rather than a field, so it also applies to
    /// assets imported before extensions were shown.
    var fileExtension: String {
        URL(fileURLWithPath: originalPath).pathExtension
    }

    /// What the user sees. Finder shows the extension, so Shelf does too.
    var displayName: String {
        fileExtension.isEmpty ? name : "\(name).\(fileExtension)"
    }

    /// Dimensions line for the inspector and list detail, when meaningful.
    var dimensionsText: String? {
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        return "\(pixelWidth) x \(pixelHeight)"
    }

    var fileSizeText: String? {
        guard fileSize > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// What the list row shows trailing: dimensions when we have them, else size.
    var detailText: String? {
        dimensionsText ?? fileSizeText
    }
}
