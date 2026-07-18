import Foundation

/// Creating and resolving security scoped bookmarks. Files are referenced in place,
/// never copied, so every read has to be wrapped in start/stop access.
enum BookmarkStore {

    static func makeBookmark(for url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        return try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves a bookmark and runs `body` with access held. Returns nil when the
    /// original is gone or its volume is offline, which the UI treats as "locate".
    static func withResolvedURL<T>(_ bookmark: Data, _ body: (URL) throws -> T) rethrows -> T? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try body(url)
    }

    /// Resolves without holding access, for showing a path or revealing in Finder.
    static func resolveURL(_ bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
