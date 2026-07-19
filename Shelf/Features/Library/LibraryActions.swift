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

    /// Categories every new library starts with. Seeded once, and never re-created
    /// if the user renames or deletes them.
    static let defaultCategoryNames = [
        "Assets", "Files", "Icons", "Websites", "App Icons", "Logos", "Design Inspo"
    ]

    private static let seedKey = "didSeedDefaultCategories"

    func seedDefaultCategoriesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.seedKey) else { return }
        defaults.set(true, forKey: Self.seedKey)

        // Seed by name so a library that already has categories keeps them and
        // still gains the defaults. Saving per insert rather than once at the end,
        // because a single failure would otherwise drop the whole batch silently.
        let existing = (try? context.fetch(FetchDescriptor<ShelfCategory>())) ?? []
        let taken = Set(existing.map(\.name))

        for name in Self.defaultCategoryNames where !taken.contains(name) {
            context.insert(ShelfCategory(name: name))
            do {
                try context.save()
            } catch {
                app.importError = "Could not create the default category \(name)."
                return
            }
        }
    }

    /// Existing libraries were seeded before dev projects existed, so this adds
    /// that one category once. Deleting it afterwards is respected.
    func seedDevProjectsCategoryIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "didSeedDevProjectsCategory"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)

        let existing = (try? context.fetch(FetchDescriptor<ShelfCategory>())) ?? []
        guard !existing.contains(where: { $0.name == "Dev Projects" }) else { return }

        let category = ShelfCategory(name: "Dev Projects")
        category.symbolName = "chevron.left.forwardslash.chevron.right"
        context.insert(category)
        try? context.save()
    }

    /// Adds a link. The Open Graph fetch only happens when the user has turned link
    /// previews on, otherwise the card falls back to the domain and title.
    func addLink(_ urlString: String, title: String?, into category: ShelfCategory?) async {
        var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !trimmed.lowercased().hasPrefix("http") {
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed), url.host() != nil else {
            app.importError = "That does not look like a valid web address."
            return
        }

        let host = url.host() ?? trimmed
        let asset = Asset(
            name: title?.isEmpty == false ? title! : host,
            kind: .link,
            bookmark: nil,
            originalPath: "",
            category: category
        )
        asset.linkURLString = url.absoluteString
        context.insert(asset)
        try? context.save()

        guard let preview = await LinkPreviewService.fetch(for: url) else { return }

        if let fetchedTitle = preview.title, title?.isEmpty != false {
            asset.name = fetchedTitle
        }
        if let imageData = preview.imageData {
            ThumbnailCache.store(imageData, id: asset.id)
            // The id alone never changes, so without this the tile that already
            // rendered a placeholder would never ask the cache again.
            asset.thumbnailRevision += 1
        }
        try? context.save()
    }

    func setIcon(_ category: ShelfCategory, symbol: String) {
        category.symbolName = symbol
        try? context.save()
    }

    /// Fronts the category's card stack with this asset's preview.
    func setAsCover(_ asset: Asset) {
        guard let category = asset.category else { return }
        category.coverAssetID = asset.id
        try? context.save()
    }

    /// Refetches one link's art and title on demand. Enables nothing: with the
    /// previews toggle off this quietly does nothing, same as everywhere else.
    func fetchLinkPreview(_ asset: Asset) async {
        guard asset.isLink, let url = asset.linkURL,
              let preview = await LinkPreviewService.fetch(for: url)
        else { return }

        if let imageData = preview.imageData {
            ThumbnailCache.store(imageData, id: asset.id)
            asset.thumbnailRevision += 1
        }
        if let title = preview.title, asset.name == asset.linkDomain {
            asset.name = title
        }
        try? context.save()
    }

    /// Fetches Open Graph art for links that have none, covering links that were
    /// added while previews were off. Runs at launch, does nothing when the
    /// toggle is off or every link already has art.
    func backfillLinkPreviews() async {
        guard LinkPreviewService.isEnabled else { return }

        let descriptor = FetchDescriptor<Asset>()
        let links = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.isLink && !ThumbnailCache.hasCached(id: $0.id) }

        for link in links {
            guard let url = link.linkURL,
                  let preview = await LinkPreviewService.fetch(for: url)
            else { continue }

            if let imageData = preview.imageData {
                ThumbnailCache.store(imageData, id: link.id)
                link.thumbnailRevision += 1
            }
            if let title = preview.title, link.name == link.linkDomain {
                link.name = title
            }
        }
        try? context.save()
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
    @discardableResult
    func importFiles(_ urls: [URL], into category: ShelfCategory?) async -> [Asset] {
        let prepared = await ImportService.prepare(urls: urls)

        guard !prepared.isEmpty else {
            app.importError = "Those files are not types Shelf collects."
            return []
        }

        var created: [Asset] = []
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
            asset.projectLanguages = file.projectLanguages
            asset.projectFileCount = file.projectFileCount
            asset.projectIsGit = file.projectIsGit
            context.insert(asset)
            created.append(asset)
        }
        try? context.save()
        return created
    }

    /// Handles shelf://add from the browser extension: downloads the image, runs
    /// it through the normal import, and keeps the page it came from as provenance.
    func addFromWeb(imageURL: URL, pageURL: URL?, title: String?) async {
        do {
            let saved = try await WebImageImporter.download(imageURL)
            let created = await importFiles([saved], into: nil)

            if let asset = created.first {
                if let pageURL {
                    asset.linkURLString = pageURL.absoluteString
                }
                if let title, !title.isEmpty {
                    asset.name = title
                }
                app.selectedAssetIDs = [asset.id]
                try? context.save()
            }
        } catch {
            app.importError = error.localizedDescription
        }
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

    /// Opens a dev project folder in Visual Studio Code.
    func openInVSCode(_ asset: Asset) {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.microsoft.VSCode"
        ) else {
            app.importError = "Visual Studio Code is not installed."
            return
        }

        handingOff(asset) { url in
            NSWorkspace.shared.open(
                [url], withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    /// Opens Terminal in the project folder and starts the Claude Code CLI.
    /// Scripting Terminal needs the automation entitlement, and macOS asks the
    /// user for consent the first time.
    func openInClaudeCode(_ asset: Asset) {
        handingOff(asset) { url in
            let path = url.path(percentEncoded: false)
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let source = """
            tell application "Terminal"
                activate
                do script "cd \\"\(path)\\" && claude"
            end tell
            """

            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if error != nil {
                app.importError = "Could not open Terminal. Check Automation permissions in System Settings."
            }
        }
    }

    func revealInFinder(_ asset: Asset) {
        handingOff(asset) { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    }

    func open(_ asset: Asset) {
        handingOff(asset) { NSWorkspace.shared.open($0) }
    }

    func quickLook(_ asset: Asset) {
        handingOff(asset) { app.quickLookURL = $0 }
    }

    /// Copies the file itself, plus the image where there is one, so pasting works
    /// in Finder and in an editor alike.
    func copy(_ asset: Asset) {
        handingOff(asset) { url in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            var items: [any NSPasteboardWriting] = [url as NSURL]
            if let image = NSImage(contentsOf: url) {
                items.append(image)
            }
            pasteboard.writeObjects(items)
        }
    }

    /// Hands a referenced file to another process. Security scoped access has to be
    /// held across the call, otherwise the sandbox refuses and the user sees
    /// "does not have permission to open". Access is released a moment later, once
    /// LaunchServices has had the chance to extend the sandbox to the receiver.
    private func handingOff(_ asset: Asset, _ body: (URL) -> Void) {
        // A link has no bookmark and needs no sandbox dance.
        if asset.isLink {
            if let url = asset.linkURL { body(url) }
            return
        }

        guard let bookmark = asset.bookmark,
              let url = BookmarkStore.resolveURL(bookmark) else { return }

        let scoped = url.startAccessingSecurityScopedResource()
        body(url)

        guard scoped else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            url.stopAccessingSecurityScopedResource()
        }
    }
}
