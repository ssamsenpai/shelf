import Foundation
import UniformTypeIdentifiers

/// The material Shelf collects. Drives the import picker, the Downloads filter, and
/// the type chips in onboarding.
enum ItemKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case image
    case svg
    case video
    case project
    case font
    case design
    case link
    case note
    case palette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: "Images"
        case .svg: "SVG"
        case .video: "Videos"
        case .project: "Dev Projects"
        case .font: "Fonts"
        case .design: "Design Files"
        case .link: "Links"
        case .note: "Notes"
        case .palette: "Palettes"
        }
    }

    var symbol: String {
        switch self {
        case .image: "photo"
        case .svg: "bezier.path"
        case .video: "film"
        case .project: "chevron.left.forwardslash.chevron.right"
        case .font: "textformat"
        case .design: "square.on.square.dashed"
        case .link: "link"
        case .note: "note.text"
        case .palette: "paintpalette"
        }
    }

    /// Kinds that come from a file on disk. Links, notes, and palettes are authored
    /// inside Shelf, so they never appear in a file picker.
    static var fileBacked: [ItemKind] { [.image, .svg, .video, .font, .design] }

    /// Content types the picker and the Downloads scanner accept for this kind.
    var contentTypes: [UTType] {
        switch self {
        case .image:
            [.png, .jpeg, .heic, .heif, .gif, .tiff, .bmp, .webP, .image]
        case .svg:
            [.svg]
        case .video:
            [.mpeg4Movie, .quickTimeMovie, .movie]
        case .project:
            [.folder]
        case .font:
            [.font, UTType(filenameExtension: "ttf"), UTType(filenameExtension: "otf"),
             UTType(filenameExtension: "woff"), UTType(filenameExtension: "woff2")]
                .compactMap { $0 }
        case .design:
            [.pdf,
             UTType("com.adobe.photoshop-image"),
             UTType("com.adobe.illustrator.ai-image"),
             UTType("com.bohemiancoding.sketch.drawing"),
             UTType(filenameExtension: "fig"),
             UTType(filenameExtension: "xd"),
             UTType(filenameExtension: "afdesign"),
             UTType(filenameExtension: "afphoto")]
                .compactMap { $0 }
        case .link, .note, .palette:
            []
        }
    }

    /// Best matching kind for a file, or nil if Shelf does not collect it.
    static func matching(_ type: UTType) -> ItemKind? {
        if type.conforms(to: .svg) { return .svg }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .font) { return .font }
        for kind in [ItemKind.design, .image] where kind.contentTypes.contains(where: type.conforms(to:)) {
            return kind
        }
        if type.conforms(to: .image) { return .image }
        return nil
    }
}

/// Archives, installers, and packaging never enter the library.
enum ImportExclusions {
    static let extensions: Set<String> = [
        "dmg", "pkg", "mpkg", "app", "zip", "tar", "gz", "bz2", "xz",
        "iso", "cdr", "sparseimage", "xip"
    ]

    static func excludes(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
