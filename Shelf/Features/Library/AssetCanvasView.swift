import SwiftUI
import ShelfUI

/// Canvas: a board that scrolls freely in both directions. Items flow into a fixed
/// number of rows and extend to the right, so wide collections stay browsable
/// without being squeezed into the window width.
struct AssetCanvasView: View {
    let assets: [Asset]
    let actions: LibraryActions

    @Environment(AppState.self) private var app

    /// Tiles are a little larger here than in the grid, since a canvas is for
    /// looking rather than for filing.
    private var tileSize: CGFloat { app.gridSize * 1.15 }

    /// Every tile is the same height, so rows line up cleanly. Only the width
    /// varies, which is what lets a wide image read as a wide tile rather than a
    /// letterboxed square. Clamped so a panorama cannot run off on its own.
    private func aspect(for asset: Asset) -> CGFloat {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 1 }
        let ratio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        return min(max(ratio, 0.55), 2.4)
    }

    /// Preview height plus the single line of filename beneath it.
    private var tileHeight: CGFloat { tileSize + 22 }

    var body: some View {
        ScrollView(.vertical) {
            // Rows wrap and flow downward, so the canvas scrolls in one direction.
            FlowLayout(spacing: Spacing.xxl) {
                ForEach(assets) { asset in
                    ThumbnailProvider(asset: asset) { image in
                        AssetTile(
                            name: asset.displayName,
                            kindTitle: asset.kind.title,
                            symbol: asset.kind.symbol,
                            thumbnail: image,
                            isSelected: app.selectedAssetIDs.contains(asset.id),
                            aspectRatio: aspect(for: asset),
                            fillsTile: true,
                            onOpen: { actions.revealInFinder(asset) }
                        )
                    }
                    .frame(width: tileSize * aspect(for: asset), height: tileHeight)
                    .contentShape(.rect)
                    .onTapGesture { app.selectedAssetIDs = [asset.id] }
                    .draggable(asset.id.uuidString)
                    .contextMenu {
                        AssetContextMenu(asset: asset, actions: actions)
                    }
                }
            }
            .padding(Spacing.xl)
            // Room for the floating switcher to sit over empty space.
            .padding(.bottom, Spacing.xxl * 2)
        }
    }
}
