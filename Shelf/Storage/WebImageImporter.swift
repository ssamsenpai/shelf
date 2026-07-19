import Foundation
import UniformTypeIdentifiers

/// Brings an image from the web onto disk so the normal import pipeline can take
/// over. This is the one place Shelf writes an asset file itself: web content has
/// no original on disk to reference, so the download in Application Support becomes
/// the original.
///
/// Runs only from an explicit "Add to My Shelf" click in the browser, never in the
/// background, so it is user initiated by construction.
enum WebImageImporter {

    enum ImportError: LocalizedError {
        case unsupportedURL
        case notAnImage

        var errorDescription: String? {
            switch self {
            case .unsupportedURL: "That image address is not supported."
            case .notAnImage: "The page did not return an image."
            }
        }
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Shelf/Web Images", directoryHint: .isDirectory)
    }

    /// Downloads the image and returns the saved file. Handles https and the
    /// data: URLs that image results sometimes use for inline thumbnails.
    static func download(_ source: URL) async throws -> URL {
        let payload: (data: Data, type: UTType?)

        switch source.scheme?.lowercased() {
        case "http", "https":
            var request = URLRequest(url: source)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)

            let mime = (response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Content-Type")?
                .components(separatedBy: ";").first?
                .trimmingCharacters(in: .whitespaces)
            payload = (data, mime.flatMap { UTType(mimeType: $0) })
        case "data":
            payload = try decodeDataURL(source)
        default:
            throw ImportError.unsupportedURL
        }

        guard let type = resolvedType(payload.type, sourceURL: source),
              type.conforms(to: .image)
        else { throw ImportError.notAnImage }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let name = suggestedName(for: source)
        let ext = type.preferredFilenameExtension ?? "png"
        var target = directory.appending(path: "\(name).\(ext)", directoryHint: .notDirectory)

        // Never overwrite an earlier save.
        var counter = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = directory.appending(path: "\(name) \(counter).\(ext)", directoryHint: .notDirectory)
            counter += 1
        }

        try payload.data.write(to: target, options: .atomic)
        return target
    }

    // MARK: Helpers

    private static func decodeDataURL(_ url: URL) throws -> (Data, UTType?) {
        let string = url.absoluteString
        guard let comma = string.firstIndex(of: ",") else { throw ImportError.unsupportedURL }

        let header = string[string.index(string.startIndex, offsetBy: 5)..<comma]
        let body = String(string[string.index(after: comma)...])

        let mime = header.components(separatedBy: ";").first ?? ""
        let type = mime.isEmpty ? nil : UTType(mimeType: mime)

        if header.contains("base64") {
            guard let data = Data(base64Encoded: body) else { throw ImportError.unsupportedURL }
            return (data, type)
        }
        guard let decoded = body.removingPercentEncoding,
              let data = decoded.data(using: .utf8)
        else { throw ImportError.unsupportedURL }
        return (data, type)
    }

    private static func resolvedType(_ fromResponse: UTType?, sourceURL: URL) -> UTType? {
        if let fromResponse { return fromResponse }
        let ext = sourceURL.pathExtension.lowercased()
        guard !ext.isEmpty else { return .png }
        return UTType(filenameExtension: ext) ?? .png
    }

    /// A readable filename from the URL, or a dated fallback for opaque ones.
    private static func suggestedName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
            .removingPercentEncoding?
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if base.isEmpty || base == "-" || url.scheme == "data" || base.count > 60 {
            let stamp = Date().formatted(.dateTime.year().month().day().hour().minute().second())
            return "Web Image \(stamp)"
        }
        return base
    }
}
