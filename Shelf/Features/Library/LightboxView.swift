import SwiftUI
import ShelfUI

/// The in app lightbox: the preview large over a dimmed backdrop, no round trip
/// through another app. Click anywhere or press Escape to close.
struct LightboxView: View {
    let asset: Asset
    let onClose: () -> Void

    @State private var image: Image?
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.55))
                .ignoresSafeArea()

            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle.shelf(Radius.medium))
                    .shelfShadow(lifted: true)
                    .padding(Spacing.xxl)
                    .scaleEffect(appeared ? 1 : 0.94)
                    .opacity(appeared ? 1 : 0)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .contentShape(.rect)
        .onTapGesture { onClose() }
        .shelfAnimation(Motion.smooth, value: appeared)
        .task {
            appeared = true
            // Full resolution from the disk cache, not the downsampled memory
            // copy: this is the one place the large bitmap is worth it.
            guard let data = await ThumbnailCache.thumbnailData(
                id: asset.id, bookmark: asset.bookmark
            ), let nsImage = NSImage(data: data) else { return }
            image = Image(nsImage: nsImage)
        }
        .accessibilityLabel("\(asset.displayName), expanded. Click to close.")
    }
}
