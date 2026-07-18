import AppKit
import SwiftUI
import ShelfUI

/// Window chrome: a glass capsule holding the traffic lights, and a glass sidebar
/// toggle beside it.
///
/// The buttons belong to AppKit's titlebar, not to any SwiftUI view, so both pieces
/// are installed there and constrained to the buttons themselves. Positioning them
/// from SwiftUI would mean guessing at titlebar metrics, which is what put the
/// capsule below the lights the first time around.
struct TrafficLightGlass: NSViewRepresentable {
    let app: AppState

    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        // The window is not attached yet at make time.
        DispatchQueue.main.async { install(from: probe) }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { install(from: nsView) }
    }

    private static let capsuleID = NSUserInterfaceItemIdentifier("ShelfTrafficLightGlass")
    private static let toggleID = NSUserInterfaceItemIdentifier("ShelfSidebarToggleGlass")

    /// Breathing room around the three buttons, which is what gives the cluster its
    /// spacing without moving the buttons themselves.
    private let capsuleInset: CGFloat = 16
    private let clusterHeight: CGFloat = 34

    private func install(from view: NSView) {
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
