import AppKit
import SwiftUI

public extension Color {
    /// The one accent token: the accent the user chose in System Settings, so
    /// Shelf matches every other well behaved Mac app. Everything else uses
    /// semantic system colors.
    static let shelfAccent = Color(nsColor: .controlAccentColor)

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

    /// Label and icon of the selected sidebar row. The system accent, same as
    /// everything else that highlights.
    static let shelfSidebarActive = Color(nsColor: .controlAccentColor)

    /// Sidebar selection fill. A soft white wash rather than a solid accent block,
    /// so the accent tinted label stays legible on top. Carries more opacity in
    /// light mode, where the sidebar material is already bright.
    static let shelfSelection = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor.white.withAlphaComponent(isDark ? 0.14 : 0.62)
    })
}


/// The primary action gradient. The system accent with a faintly lightened top,
/// sitting close enough together that the fill reads as a solid with an inner
/// light rather than as a gradient. Follows the accent the user chose in System
/// Settings. Fills only: labels on top of it stay white.
public enum ShelfGradient {
    public static let bottom = Color(nsColor: .controlAccentColor)

    public static let top = Color(nsColor: NSColor(name: nil) { _ in
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .controlAccentColor
        return accent.blended(withFraction: 0.12, of: .white) ?? accent
    })

    public static let primary = LinearGradient(
        colors: [bottom, top],
        startPoint: .bottom,
        endPoint: .top
    )
}
