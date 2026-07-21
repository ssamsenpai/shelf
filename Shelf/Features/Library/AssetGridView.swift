import SwiftUI
import ShelfUI

/// Preview first grid. Tiles resize with the size control in the toolbar.
struct AssetGridView: View {
    let assets: [Asset]
    let actions: LibraryActions

    @Environment(AppState.self) private var app

    var body: some View {
        // Equal width columns, heights follow each preview's own ratio.
        MasonryLayout(columnWidth: app.gridSize, spacing: Spacing.l) {
            ForEach(assets) { asset in
                ThumbnailProvider(asset: asset) { loaded in
                    MasonryTile(
                        name: asset.displayName,
                        kindTitle: asset.kind.title,
                        symbol: asset.kind.symbol,
                        thumbnail: loaded?.image,
                        aspectRatio: tileRatio(asset: asset, loaded: loaded),
                        showsTransparency: loaded?.hasTransparency ?? false,
                        isSelected: app.selectedAssetIDs.contains(asset.id),
                        onOpen: { actions.revealInFinder(asset) }
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

    /// The preview's true ratio, clamped so one panorama or endless screenshot
    /// cannot dominate a column. Previewless assets get a calm square.
    private func tileRatio(asset: Asset, loaded: LoadedThumbnail?) -> CGFloat {
        let stored: CGFloat? = asset.pixelWidth > 0 && asset.pixelHeight > 0
            ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
            : nil
        let ratio = loaded?.aspectRatio ?? stored ?? 1
        return min(max(ratio, 0.45), 2.6)
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
