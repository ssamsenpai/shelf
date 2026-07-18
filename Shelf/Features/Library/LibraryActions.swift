import Foundation
import SwiftData
import SwiftUI

/// Writes to the library. Held by the views that own a model context so the actions
/// stay in one place instead of scattered through the view tree.
@MainActor
struct LibraryActions {
    let context: ModelContext
    let app: AppState

    /// Creates a category and drops straight into inline rename, like Finder.
    @discardableResult
    func createCategory() -> ShelfCategory {
        let category = ShelfCategory(name: "New Category")
        context.insert(category)
        try? context.save()

        app.selection = .category(category.id)
        app.renamingCategoryID = category.id
        return category
    }

    func rename(_ category: ShelfCategory, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        category.name = trimmed.isEmpty ? "New Category" : trimmed
        try? context.save()
    }

    func delete(_ category: ShelfCategory) {
        // Assets survive, they just fall back to Inbox.
        for asset in category.assets {
            asset.category = nil
        }
        context.delete(category)
        try? context.save()

        if app.selection == .category(category.id) {
            app.selection = .allItems
        }
    }

    /// Imports files by reference. Nothing is ever copied.
    func importFiles(_ urls: [URL], into category: ShelfCategory?) async {
        let prepared = await ImportService.prepare(urls: urls)

        guard !prepared.isEmpty else {
            app.importError = "Those files are not types Shelf collects."
            return
        }

        for file in prepared {
            let asset = Asset(
                name: file.name,
                kind: file.kind,
                bookmark: file.bookmark,
                originalPath: file.originalPath,
                fileSize: file.fileSize,
                pixelWidth: file.pixelWidth,
                pixelHeight: file.pixelHeight,
                contentCreatedAt: file.createdAt,
                contentModifiedAt: file.modifiedAt,
                dominantColors: file.dominantColors,
                category: category
            )
            context.insert(asset)
        }
        try? context.save()
    }

    func move(_ assets: [Asset], to category: ShelfCategory?) {
        for asset in assets {
            asset.category = category
        }
        try? context.save()
    }

    func move(ids: [UUID], to category: ShelfCategory?) {
        let descriptor = FetchDescriptor<Asset>()
        guard let all = try? context.fetch(descriptor) else { return }
        move(all.filter { ids.contains($0.id) }, to: category)
    }

    /// Removes from the library only. The user's file is left exactly where it is.
    func remove(_ assets: [Asset]) {
        for asset in assets {
            ThumbnailCache.removeCached(id: asset.id)
            context.delete(asset)
        }
        try? context.save()
        app.selectedAssetIDs.removeAll()
    }

    func revealInFinder(_ asset: Asset) {
        guard let bookmark = asset.bookmark,
              let url = BookmarkStore.resolveURL(bookmark) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(_ asset: Asset) {
        guard let bookmark = asset.bookmark,
              let url = BookmarkStore.resolveURL(bookmark) else { return }
        NSWorkspace.shared.open(url)
    }

    func quickLook(_ asset: Asset) {
        guard let bookmark = asset.bookmark else { return }
        app.quickLookURL = BookmarkStore.resolveURL(bookmark)
    }
}
