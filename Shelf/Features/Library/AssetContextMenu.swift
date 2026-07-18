import SwiftData
import SwiftUI

/// Right click actions on an asset. Removing never touches the user's file.
struct AssetContextMenu: View {
    let asset: Asset
    let actions: LibraryActions

    @Environment(AppState.self) private var app
    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]

    var body: some View {
        Button("Open") { actions.open(asset) }
        Button("Quick Look") { actions.quickLook(asset) }
        Button("Reveal in Finder") { actions.revealInFinder(asset) }
        Button("Copy") { actions.copy(asset) }

        Divider()

        Menu("Move to Category") {
            ForEach(categories) { category in
                Button(category.name) { actions.move([asset], to: category) }
            }
            if !categories.isEmpty {
                Divider()
            }
            Button("No Category") { actions.move([asset], to: nil) }
        }

        if asset.category != nil {
            Button("Set as Category Cover") { actions.setAsCover(asset) }
        }

        Button("Get Info") {
            app.selectedAssetIDs = [asset.id]
            app.inspectorPresented = true
        }

        Divider()

        Button("Remove from Shelf", role: .destructive) {
            actions.remove([asset])
        }
    }
}
