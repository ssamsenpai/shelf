import SwiftUI
import ShelfUI

/// Canvas: a board of previews at a single height, widths following the content.
/// Rows wrap and the whole thing scrolls vertically. Names are omitted here, this
/// view is for looking rather than for reading.
struct AssetCanvasView: View {
    let assets: [Asset]
    let actions: LibraryActions

    @Environment(AppState.self) private var app

    /// Links have no visual of their own worth showing on a board, so they stay in
    /// the grid and list views.
    private var visibleAssets: [Asset] {
        assets.filter { !$0.isLink }
    }

    /// Tiles are a little larger here than in the grid, since a canvas is for
    /// looking rather than for filing.
    private var tileHeight: CGFloat { app.gridSize * 1.15 }

    var body: some View {
        ScrollView(.vertical) {
            // Rows wrap and flow downward, so the canvas scrolls in one direction.
            FlowLayout(spacing: Spacing.xxl) {
                ForEach(visibleAssets) { asset in
                    tile(for: asset)
                }
            }
            .padding(Spacing.xl)
            // Room for the floating switcher to sit over empty space.
            .padding(.bottom, Spacing.xxl * 3)
        }
    }

    private func tile(for asset: Asset) -> some View {
        ThumbnailProvider(asset: asset) { loaded in
            // Measured from the rendered preview first, because PDFs and other
            // vector kinds carry no pixel dimensions of their own and would
            // otherwise fall back to a square.
            let ratio = clamped(loaded?.aspectRatio ?? storedAspect(for: asset))

            AssetTile(
                name: asset.displayName,
                kindTitle: asset.kind.title,
                symbol: asset.kind.symbol,
                thumbnail: loaded?.image,
                isSelected: app.selectedAssetIDs.contains(asset.id),
                aspectRatio: ratio,
                fillsTile: true,
                showsName: false,
                onOpen: { actions.revealInFinder(asset) }
            )
            .frame(width: tileHeight * ratio, height: tileHeight)
            .contentShape(.rect)
            .onTapGesture { app.selectedAssetIDs = [asset.id] }
            .draggable(asset.id.uuidString)
            .contextMenu {
                AssetContextMenu(asset: asset, actions: actions)
            }
        }
    }

    private func storedAspect(for asset: Asset) -> CGFloat {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 1 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    /// Keeps a panorama or a very tall export from running away with the row.
    private func clamped(_ ratio: CGFloat) -> CGFloat {
        min(max(ratio, 0.55), 2.4)
    }
}
