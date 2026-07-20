import SwiftUI
import ShelfUI

/// List view. Native multi select and arrow key navigation come from `List` itself,
/// which is also why this owns the scrolling rather than sitting inside a ScrollView.
struct AssetListView: View {
    let assets: [Asset]
    let actions: LibraryActions
    /// Shown as a leading section in browse views. Empty inside a category.
    var categories: [ShelfCategory] = []

    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app

        return List(selection: $app.selectedAssetIDs) {
            if !categories.isEmpty {
                Section("Collections") {
                    CategoryFolderGrid(categories: categories, actions: actions, showsHeader: false)
                        .padding(.vertical, Spacing.s)
                        .listRowSeparator(.hidden)
                }
            }

            Section(categories.isEmpty ? "" : "Files") {
                ForEach(assets) { asset in
                    ThumbnailProvider(asset: asset) { loaded in
                        AssetRow(
                            name: asset.displayName,
                            kindTitle: asset.kind.title,
                            symbol: asset.kind.symbol,
                            detail: asset.detailText,
                            thumbnail: loaded?.image
                        )
                    }
                    .draggable(asset.id.uuidString)
                    .contextMenu {
                        AssetContextMenu(asset: asset, actions: actions)
                    }
                    .tag(asset.id)
                }
            }
        }
        .listStyle(.inset)
    }
}
