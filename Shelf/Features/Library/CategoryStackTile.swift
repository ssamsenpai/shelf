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
            isDropTarget: isDropTarget
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

    private var newestAssets: [Asset] {
        category.assets
            .sorted { $0.addedAt > $1.addedAt }
            .prefix(3)
            .map { $0 }
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
