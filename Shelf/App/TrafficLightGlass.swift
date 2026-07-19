import AppKit
import SwiftUI
import ShelfUI

/// Window chrome: a glass capsule holding the traffic lights, and a glass sidebar
/// toggle beside it.
///
/// The buttons belong to AppKit's titlebar, not to any SwiftUI view, so both pieces
/// are installed there and constrained to the buttons themselves. The buttons stay
/// where AppKit puts them: overriding their frames drifts across layout passes.
///
/// The close button sits nearly flush with the window corner, so centering a taller
/// capsule on it would push past the top and left edges and clip flat. Margins from
/// the window edges are required constraints; hugging the buttons is optional.
///
/// In fullscreen the system hides the titlebar, so the glass hides with it rather
/// than floating over content.
struct TrafficLightGlass: NSViewRepresentable {
    let app: AppState

    private static let capsuleID = NSUserInterfaceItemIdentifier("ShelfTrafficLightGlass")
    private static let toggleID = NSUserInterfaceItemIdentifier("ShelfSidebarToggleGlass")

    private let capsuleInset: CGFloat = 18
    private let clusterHeight: CGFloat = 34

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        // The window is not attached yet at make time.
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

        // Staying inside the window is required. Hugging the buttons is preferred,
        // and gives way when the buttons sit too near the corner.
        let hugLeading = capsule.leadingAnchor.constraint(
            equalTo: close.leadingAnchor, constant: -capsuleInset
        )
        hugLeading.priority = .defaultHigh

        let hugCenterY = capsule.centerYAnchor.constraint(equalTo: close.centerYAnchor)
        hugCenterY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            capsule.leadingAnchor.constraint(
                greaterThanOrEqualTo: titlebar.leadingAnchor, constant: Spacing.m
            ),
            capsule.topAnchor.constraint(
                greaterThanOrEqualTo: titlebar.topAnchor, constant: Spacing.xs
            ),
            hugLeading,
            hugCenterY,
            capsule.trailingAnchor.constraint(equalTo: zoom.trailingAnchor, constant: capsuleInset),
            capsule.heightAnchor.constraint(equalToConstant: clusterHeight),

            toggle.leadingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: Spacing.s),
            toggle.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            toggle.widthAnchor.constraint(equalToConstant: clusterHeight),
            toggle.heightAnchor.constraint(equalToConstant: clusterHeight)
        ])

        coordinator.watch(window: window, capsule: capsule, toggle: toggle)
    }

    /// Hides the glass while the window is fullscreen, where the system hides the
    /// titlebar and anything left in it would float over content.
    @MainActor
    final class Coordinator: NSObject {
        /// Boxed so the nonisolated deinit can release them: a main actor isolated
        /// class cannot touch non sendable stored state on the way out.
        private let observers = ObserverBox()
        private weak var window: NSWindow?
        private weak var capsule: NSView?
        private weak var toggle: NSView?

        func watch(window: NSWindow, capsule: NSView, toggle: NSView) {
            self.capsule = capsule
            self.toggle = toggle

            setHidden(window.styleMask.contains(.fullScreen))

            guard self.window !== window else { return }
            self.window = window

            let center = NotificationCenter.default
            let pairs: [(Notification.Name, Bool)] = [
                (NSWindow.willEnterFullScreenNotification, true),
                (NSWindow.willExitFullScreenNotification, false)
            ]
            for (name, hidden) in pairs {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.setHidden(hidden) }
                }
                observers.tokens.append(token)
            }
        }

        private func setHidden(_ hidden: Bool) {
            capsule?.isHidden = hidden
            toggle?.isHidden = hidden
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
