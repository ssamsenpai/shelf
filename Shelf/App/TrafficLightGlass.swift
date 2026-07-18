import AppKit
import SwiftUI
import ShelfUI

/// Puts a glass capsule behind the window's traffic lights.
///
/// The buttons belong to AppKit's titlebar, not to any SwiftUI view, so the capsule
/// is installed as a sibling constrained to the buttons themselves. Positioning it
/// from SwiftUI would mean guessing at titlebar metrics, which lands it in the wrong
/// place the moment the window style or the system changes.
struct TrafficLightGlass: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        // The window is not attached yet at make time.
        DispatchQueue.main.async { install(from: probe) }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { install(from: nsView) }
    }

    private static let identifier = NSUserInterfaceItemIdentifier("ShelfTrafficLightGlass")

    private func install(from view: NSView) {
        guard let window = view.window,
              let close = window.standardWindowButton(.closeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let titlebar = close.superview
        else { return }

        // Only ever one, even though updateNSView runs on every layout pass.
        guard !titlebar.subviews.contains(where: { $0.identifier == Self.identifier }) else {
            return
        }

        let host = NSHostingView(rootView: GlassCapsule())
        host.identifier = Self.identifier
        host.translatesAutoresizingMaskIntoConstraints = false

        // Below the buttons, so it reads as a container holding them.
        titlebar.addSubview(host, positioned: .below, relativeTo: close)

        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: close.leadingAnchor, constant: -Spacing.m),
            host.trailingAnchor.constraint(equalTo: zoom.trailingAnchor, constant: Spacing.m),
            host.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            host.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private struct GlassCapsule: View {
        var body: some View {
            Color.clear
                .glassEffect(.regular, in: .capsule)
                .allowsHitTesting(false)
        }
    }
}
