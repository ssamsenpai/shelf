import SwiftUI
import ShelfUI

/// A category in the content area, drawn as a stack of its own newest items.
struct CategoryStackTile: View {
    let category: ShelfCategory
    let isSelected: Bool
    let isDropTarget: Bool

    @State private var previews: [Image?] = []

    var body: some View {
        StackedCards(
            name: category.name,
            count: category.itemCount,
            previews: previews,
            isSelected: isSelected,
            isDropTarget: isDropTarget,
            placeholderSymbol: category.symbolName
        )
        .task(id: previewKey) {
            previews = await loadPreviews()
        }
    }

    /// Reloads when the newest few items change, so the stack keeps up with edits
    /// without reloading on every unrelated redraw.
    private var previewKey: String {
        newestAssets.map(\.id.uuidString).joined()
    }

    /// The chosen cover fronts the stack, then the newest of the rest behind it.
    private var newestAssets: [Asset] {
        let sorted = category.assets.sorted { $0.addedAt > $1.addedAt }

        guard let coverID = category.coverAssetID,
              let cover = sorted.first(where: { $0.id == coverID })
        else {
            return Array(sorted.prefix(3))
        }

        return [cover] + sorted.filter { $0.id != coverID }.prefix(2)
    }

    private func loadPreviews() async -> [Image?] {
        var images: [Image?] = []

        for asset in newestAssets {
            let data = await ThumbnailCache.thumbnailData(id: asset.id, bookmark: asset.bookmark)
            if let data, let nsImage = NSImage(data: data) {
                images.append(Image(nsImage: nsImage))
            } else {
                images.append(nil)
            }
        }
        return images
    }
}
