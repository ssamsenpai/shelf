import SwiftUI
import ShelfUI

/// Preview first grid. Tiles resize with the size control in the toolbar.
struct AssetGridView: View {
    let assets: [Asset]
    let actions: LibraryActions

    @Environment(AppState.self) private var app

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: app.gridSize, maximum: app.gridSize * 1.5), spacing: Spacing.l)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.l) {
            ForEach(assets) { asset in
                ThumbnailProvider(asset: asset) { image in
                    AssetTile(
                        name: asset.name,
                        kindTitle: asset.kind.title,
                        symbol: asset.kind.symbol,
                        thumbnail: image,
                        isSelected: app.selectedAssetIDs.contains(asset.id)
                    )
                }
                .contentShape(.rect)
                .onTapGesture { select(asset) }
                .onTapGesture(count: 2) { actions.open(asset) }
                .draggable(asset.id.uuidString)
                .contextMenu {
                    AssetContextMenu(asset: asset, actions: actions)
                }
            }
        }
    }

    /// Command click extends the selection, a plain click replaces it.
    private func select(_ asset: Asset) {
        if NSEvent.modifierFlags.contains(.command) {
            if app.selectedAssetIDs.contains(asset.id) {
                app.selectedAssetIDs.remove(asset.id)
            } else {
                app.selectedAssetIDs.insert(asset.id)
            }
        } else if NSEvent.modifierFlags.contains(.shift), !app.selectedAssetIDs.isEmpty {
            extendSelection(to: asset)
        } else {
            app.selectedAssetIDs = [asset.id]
        }

        if !app.inspectorPresented { return }
    }

    private func extendSelection(to asset: Asset) {
        guard let target = assets.firstIndex(where: { $0.id == asset.id }),
              let anchor = assets.firstIndex(where: { app.selectedAssetIDs.contains($0.id) })
        else {
            app.selectedAssetIDs = [asset.id]
            return
        }

        let range = anchor <= target ? anchor...target : target...anchor
        app.selectedAssetIDs.formUnion(assets[range].map(\.id))
    }
}
