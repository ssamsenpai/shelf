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
        newestAssets.map { "\($0.id)-\($0.thumbnailRevision)" }.joined()
    }

    /// The chosen cover fronts the stack. The rest are picked for visual quality,
    /// not recency: photographs first, then PNG, other visuals, link art, and dev
    /// project folders only when nothing better exists. Ties break newest first.
    private var newestAssets: [Asset] {
        let sorted = category.assets.sorted { lhs, rhs in
            let l = coverPriority(lhs)
            let r = coverPriority(rhs)
            if l != r { return l < r }
            return lhs.addedAt > rhs.addedAt
        }

        guard let coverID = category.coverAssetID,
              let cover = sorted.first(where: { $0.id == coverID })
        else {
            return Array(sorted.prefix(3))
        }

        return [cover] + sorted.filter { $0.id != coverID }.prefix(2)
    }

    private func coverPriority(_ asset: Asset) -> Int {
        if asset.isProject { return 5 }
        if asset.isLink {
            // A link earns its slot only when its Open Graph art is on disk.
            return ThumbnailCache.hasCached(id: asset.id) ? 3 : 6
        }

        switch asset.kind {
        case .image:
            switch asset.fileExtension.lowercased() {
            case "jpg", "jpeg": return 0
            case "png": return 1
            default: return 2
            }
        case .svg, .video:
            return 2
        default:
            return 4
        }
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
