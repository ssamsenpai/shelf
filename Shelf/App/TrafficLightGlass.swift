import AppKit
import SwiftUI
import ShelfUI

/// Window chrome: a glass capsule holding the traffic lights, and a glass sidebar
/// toggle beside it, both nudged clear of the sidebar edge.
///
/// The buttons belong to AppKit's titlebar, not to any SwiftUI view, so everything
/// here is installed there and constrained to the buttons themselves. Positioning
/// from SwiftUI would mean guessing at titlebar metrics, which is what put the
/// capsule below the lights the first time around.
///
/// AppKit restores the buttons to their standard origins on every titlebar layout,
/// so the offset is reapplied on resize and fullscreen transitions. Baselines are
/// captured once, before anything moves, so repeated passes cannot drift.
struct TrafficLightGlass: NSViewRepresentable {
    let app: AppState

    /// Nudge away from the sidebar edge.
    private static let offset = CGSize(width: 10, height: 6)

    private static let capsuleID = NSUserInterfaceItemIdentifier("ShelfTrafficLightGlass")
    private static let toggleID = NSUserInterfaceItemIdentifier("ShelfSidebarToggleGlass")

    private let capsuleInset: CGFloat = 16
    private let clusterHeight: CGFloat = 34

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        DispatchQueue.main.async { install(from: probe, coordinator: context.coordinator) }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { install(from: nsView, coordinator: context.coordinator) }
    }

    private func install(from view: NSView, coordinator: Coordinator) {
        guard let window = view.window,
              let close = window.standardWindowButton(.closeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let titlebar = close.superview
        else { return }

        coordinator.attach(to: window, offset: Self.offset)

        // Only ever one of each, though updateNSView runs on every layout pass.
        guard !titlebar.subviews.contains(where: { $0.identifier == Self.capsuleID }) else {
            return
        }

        let capsule = NSHostingView(rootView: GlassCapsule())
        capsule.identifier = Self.capsuleID
        capsule.translatesAutoresizingMaskIntoConstraints = false
        // Below the buttons, so it reads as a container holding them.
        titlebar.addSubview(capsule, positioned: .below, relativeTo: close)

        let toggle = NSHostingView(rootView: SidebarToggle(app: app))
        toggle.identifier = Self.toggleID
        toggle.translatesAutoresizingMaskIntoConstraints = false
        titlebar.addSubview(toggle, positioned: .above, relativeTo: nil)

        NSLayoutConstraint.activate([
            capsule.leadingAnchor.constraint(equalTo: close.leadingAnchor, constant: -capsuleInset),
            capsule.trailingAnchor.constraint(equalTo: zoom.trailingAnchor, constant: capsuleInset),
            capsule.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            capsule.heightAnchor.constraint(equalToConstant: clusterHeight),

            toggle.leadingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: Spacing.s),
            toggle.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            toggle.widthAnchor.constraint(equalToConstant: clusterHeight),
            toggle.heightAnchor.constraint(equalToConstant: clusterHeight)
        ])
    }

    /// Keeps the traffic lights at their offset position across layout passes.
    @MainActor
    final class Coordinator: NSObject {
        private var baselines: [NSWindow.ButtonType: CGPoint] = [:]
        /// Boxed so the nonisolated deinit can release them: a main actor isolated
        /// class cannot touch non sendable stored state on the way out.
        private let observers = ObserverBox()
        private weak var window: NSWindow?
        private var offset: CGSize = .zero

        private static let buttonTypes: [NSWindow.ButtonType] = [
            .closeButton, .miniaturizeButton, .zoomButton
        ]

        func attach(to window: NSWindow, offset: CGSize) {
            guard self.window !== window else {
                apply()
                return
            }

            self.window = window
            self.offset = offset
            captureBaselines()
            apply()

            let center = NotificationCenter.default
            for name in [
                NSWindow.didResizeNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didBecomeKeyNotification
            ] {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.apply() }
                }
                observers.tokens.append(token)
            }

            // Window level notifications are not enough: any titlebar layout, such
            // as switching pages, snaps the buttons back to their standard origins.
            // Watching each button's own frame is what actually catches that.
            for type in Self.buttonTypes {
                guard let button = window.standardWindowButton(type) else { continue }
                button.postsFrameChangedNotifications = true

                let token = center.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: button,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.apply() }
                }
                observers.tokens.append(token)
            }
        }

        /// Captured before the first move, so reapplying is idempotent.
        private func captureBaselines() {
            guard let window else { return }
            for type in Self.buttonTypes {
                guard let button = window.standardWindowButton(type) else { continue }
                baselines[type] = button.frame.origin
            }
        }

        private var isApplying = false

        private func apply() {
            guard let window, !isApplying else { return }
            isApplying = true
            defer { isApplying = false }

            for type in Self.buttonTypes {
                guard let button = window.standardWindowButton(type),
                      let baseline = baselines[type]
                else { continue }

                let flipped = button.superview?.isFlipped ?? false
                let origin = CGPoint(
                    x: baseline.x + offset.width,
                    y: flipped ? baseline.y + offset.height : baseline.y - offset.height
                )
                if button.frame.origin != origin {
                    button.setFrameOrigin(origin)
                }
            }

            // The glass is constrained to the buttons, so it has to re-solve.
            window.standardWindowButton(.closeButton)?.superview?.layoutSubtreeIfNeeded()
        }

        deinit {
            observers.removeAll()
        }
    }

    /// Holds notification tokens so they can be released from a nonisolated deinit.
    private final class ObserverBox: @unchecked Sendable {
        var tokens: [any NSObjectProtocol] = []

        func removeAll() {
            let center = NotificationCenter.default
            for token in tokens {
                center.removeObserver(token)
            }
            tokens.removeAll()
        }
    }

    private struct GlassCapsule: View {
        var body: some View {
            Color.clear
                .glassEffect(.regular, in: .capsule)
                .allowsHitTesting(false)
        }
    }

    /// Lives beside the traffic lights rather than in the toolbar, which is why the
    /// toolbar's own sidebar item is removed.
    private struct SidebarToggle: View {
        let app: AppState

        var body: some View {
            Button {
                app.columnVisibility = app.columnVisibility == .all ? .detailOnly : .all
            } label: {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .help("Hide or show the sidebar")
        }
    }
}
