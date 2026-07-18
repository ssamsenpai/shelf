import SwiftUI

/// The single shadow token. Soft, low, and used only where depth carries meaning:
/// a lifted folder on hover, an item being dragged. Never as decoration.
public enum ShelfShadow {
    public static let color = Color.black.opacity(0.08)
    public static let radius: CGFloat = 8
    public static let y: CGFloat = 2
}

public extension View {
    /// Applies the soft shadow token. `lifted` is false in the resting state so the
    /// shadow can animate in rather than sit under every surface.
    func shelfShadow(lifted: Bool = true) -> some View {
        shadow(
            color: lifted ? ShelfShadow.color : .clear,
            radius: lifted ? ShelfShadow.radius : 0,
            y: lifted ? ShelfShadow.y : 0
        )
    }
}
