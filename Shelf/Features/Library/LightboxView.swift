import AVFoundation
import AVKit
import SwiftUI
import ShelfUI

/// The in app lightbox: the preview large over a dimmed backdrop, no round trip
/// through another app. Images show full resolution, videos play in a native
/// AVKit surface with a Liquid Glass control bar. Click the backdrop or press
/// Escape to close.
struct LightboxView: View {
    let asset: Asset
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.55))
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { onClose() }

            Group {
                if asset.kind == .video {
                    VideoLightbox(asset: asset)
                } else {
                    ImageLightbox(asset: asset, onClose: onClose)
                }
            }
            .padding(Spacing.xxl)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .shelfAnimation(Motion.smooth, value: appeared)
        .onAppear { appeared = true }
        .accessibilityLabel("\(asset.displayName), expanded. Press Escape to close.")
    }
}

// MARK: - Images

private struct ImageLightbox: View {
    let asset: Asset
    let onClose: () -> Void

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle.shelf(Radius.medium))
                    .shelfShadow(lifted: true)
                    .onTapGesture { onClose() }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .task {
            // Full resolution from the disk cache, not the downsampled memory
            // copy: this is the one place the large bitmap is worth it.
            guard let data = await ThumbnailCache.thumbnailData(
                id: asset.id, bookmark: asset.bookmark
            ), let nsImage = NSImage(data: data) else { return }
            image = Image(nsImage: nsImage)
        }
    }
}

// MARK: - Video

/// Native playback without the system chrome, so the glass control bar below is
/// the only UI. Security scoped access is held for the player's lifetime.
private struct VideoLightbox: View {
    let asset: Asset

    @State private var player: AVPlayer?
    @State private var scopedURL: URL?
    @State private var isPlaying = false
    @State private var duration: Double = 0
    @State private var time: Double = 0
    @State private var isMuted = false
    @State private var isScrubbing = false
    @State private var timeObserver: Any?

    var body: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                if let player {
                    PlayerSurface(player: player)
                        .clipShape(RoundedRectangle.shelf(Radius.medium))
                        .shelfShadow(lifted: true)
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
            .aspectRatio(videoAspect, contentMode: .fit)
            .contentShape(.rect)
            .onTapGesture { togglePlayback() }

            controls
        }
        .onAppear { load() }
        .onDisappear { teardown() }
    }

    private var videoAspect: CGFloat {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 16 / 9 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    /// The glass control bar: play, scrubber, time, mute. Glass belongs to this
    /// floating control layer, never to the video content itself.
    private var controls: some View {
        GlassEffectContainer(spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 22)
                }
                .buttonStyle(.plain)

                Text(timestamp(time))
                    .font(.shelfNumeric(11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { time },
                        set: { seek(to: $0) }
                    ),
                    in: 0...max(duration, 0.01)
                ) { editing in
                    isScrubbing = editing
                }
                .controlSize(.small)
                .frame(width: 260)

                Text(timestamp(duration))
                    .font(.shelfNumeric(11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)

                Button {
                    isMuted.toggle()
                    player?.isMuted = isMuted
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.l)
            .frame(height: 44)
            .glassEffect(.regular, in: .capsule)
        }
    }

    // MARK: Playback

    private func load() {
        guard let bookmark = asset.bookmark,
              let url = BookmarkStore.resolveURL(bookmark) else { return }

        // Held until the lightbox closes: AVFoundation reads lazily.
        _ = url.startAccessingSecurityScopedResource()
        scopedURL = url

        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        self.player = player

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { current in
            Task { @MainActor in
                if !isScrubbing { time = current.seconds }
            }
        }

        Task {
            if let loaded = try? await player.currentItem?.asset.load(.duration) {
                duration = loaded.seconds.isFinite ? loaded.seconds : 0
            }
            player.play()
            isPlaying = true
        }
    }

    private func teardown() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player?.pause()
        player = nil
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            // Replay from the top once the end is reached.
            if duration > 0, time >= duration - 0.05 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func seek(to seconds: Double) {
        time = seconds
        player?.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func timestamp(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Bare AVKit surface: native rendering, no system chrome.
private struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
    }
}
