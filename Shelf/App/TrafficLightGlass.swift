import AppKit
import SwiftUI
import ShelfUI

/// A glass capsule behind the window's traffic lights.
///
/// The buttons belong to AppKit's titlebar, not to any SwiftUI view, so the capsule
/// is installed there and constrained to the buttons themselves. The buttons stay
/// where AppKit puts them: overriding their frames drifts across layout passes.
///
/// Only the capsule lives here. The sidebar toggle is a real toolbar item, so the
/// toolbar lays it out and the window title can never slide underneath it.
///
/// In fullscreen the system hides the titlebar, so the capsule hides with it.
struct TrafficLightGlass: NSViewRepresentable {

    private static let capsuleID = NSUserInterfaceItemIdentifier("ShelfTrafficLightGlass")

    /// Padding around the buttons inside the capsule.
    private let capsuleInset: CGFloat = 14
    private let capsuleHeight: CGFloat = 34

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

        // Only ever one, though updateNSView runs on every layout pass.
        guard !titlebar.subviews.contains(where: { $0.identifier == Self.capsuleID }) else {
            return
        }

        let capsule = NSHostingView(rootView: GlassCapsule())
        capsule.identifier = Self.capsuleID
        capsule.translatesAutoresizingMaskIntoConstraints = false
        // Below the buttons, so it reads as a container holding them.
        titlebar.addSubview(capsule, positioned: .below, relativeTo: close)

        // Symmetric padding around the buttons is preferred. Staying off the window
        // edge is required and wins when the buttons sit too near the corner.
        let hugLeading = capsule.leadingAnchor.constraint(
            equalTo: close.leadingAnchor, constant: -capsuleInset
        )
        hugLeading.priority = .defaultHigh

        NSLayoutConstraint.activate([
            capsule.leadingAnchor.constraint(
                greaterThanOrEqualTo: titlebar.leadingAnchor, constant: Spacing.s
            ),
            hugLeading,
            capsule.trailingAnchor.constraint(equalTo: zoom.trailingAnchor, constant: capsuleInset),
            capsule.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            capsule.heightAnchor.constraint(equalToConstant: capsuleHeight)
        ])

        coordinator.watch(window: window, capsule: capsule)
    }

    /// Hides the capsule while the window is fullscreen, where the system hides the
    /// titlebar and anything left in it would float over content.
    @MainActor
    final class Coordinator: NSObject {
        /// Boxed so the nonisolated deinit can release them: a main actor isolated
        /// class cannot touch non sendable stored state on the way out.
        private let observers = ObserverBox()
        private weak var window: NSWindow?
        private weak var capsule: NSView?

        func watch(window: NSWindow, capsule: NSView) {
            self.capsule = capsule

            capsule.isHidden = window.styleMask.contains(.fullScreen)

            guard self.window !== window else { return }
            self.window = window

            let center = NotificationCenter.default
            let pairs: [(Notification.Name, Bool)] = [
                (NSWindow.willEnterFullScreenNotification, true),
                (NSWindow.willExitFullScreenNotification, false)
            ]
            for (name, hidden) in pairs {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.capsule?.isHidden = hidden }
                }
                observers.tokens.append(token)
            }
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
}
