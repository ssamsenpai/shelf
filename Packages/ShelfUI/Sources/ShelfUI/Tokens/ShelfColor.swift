import AppKit
import SwiftUI

public extension Color {
    /// The one accent token. Defined in the package asset catalog so light and dark
    /// are automatic. Everything else uses semantic system colors.
    static let shelfAccent = Color("ShelfAccent", bundle: .module)

    /// Window and content surfaces. Named so no view reaches for AppKit directly.
    static let shelfWindow = Color(nsColor: .windowBackgroundColor)
    static let shelfContent = Color(nsColor: .controlBackgroundColor)
    /// Quiet fill for empty wells and placeholder bodies.
    static let shelfWell = Color(nsColor: .quaternarySystemFill)
    /// Meaningful separators only.
    static let shelfSeparator = Color(nsColor: .separatorColor)

    /// A raised chip sitting on glass, such as the selected segment of a floating
    /// control. Near white in light, a lifted gray in dark.
    static let shelfRaised = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.22)
            : NSColor.white.withAlphaComponent(0.95)
    })

    /// Label and icon of the selected sidebar row. Slightly lighter in dark mode,
    /// where the exact light mode blue loses contrast against the material.
    static let shelfSidebarActive = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0.25, green: 0.62, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.0, green: 0.447, blue: 0.969, alpha: 1)
    })

    /// Sidebar selection fill. A soft white wash rather than a solid accent block,
    /// so the accent tinted label stays legible on top. Carries more opacity in
    /// light mode, where the sidebar material is already bright.
    static let shelfSelection = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor.white.withAlphaComponent(isDark ? 0.14 : 0.62)
    })
}
