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

    private var rows: [GridItem] {
        Array(
            repeating: GridItem(.fixed(tileSize + 28), spacing: Spacing.l, alignment: .top),
            count: rowCount
        )
    }

    /// Row height is fixed and width follows the asset, so a wide image reads as a
    /// wide tile instead of a letterboxed square. Clamped so a panorama or a very
    /// tall export cannot dominate the row.
    private func aspect(for asset: Asset) -> CGFloat {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 1 }
        let ratio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        return min(max(ratio, 0.55), 2.4)
    }

    /// Fewer rows for small collections, so a handful of items does not stretch
    /// into a thin ribbon.
    private var rowCount: Int {
        switch assets.count {
        case 0...3: 1
        case 4...8: 2
        default: 3
        }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyHGrid(rows: rows, alignment: .top, spacing: Spacing.l) {
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
                    .frame(width: tileSize * aspect(for: asset))
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
        .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
    }
}
