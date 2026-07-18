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
}
