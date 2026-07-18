import SwiftUI

/// Corner radii. Concentric where one shape nests inside another.
public enum Radius {
    /// 8, for chips, swatches, small controls.
    public static let small: CGFloat = 8
    /// 12, for cards and rows.
    public static let medium: CGFloat = 12
    /// 16, for panels and sheets.
    public static let large: CGFloat = 16
    /// 14, reserved for the folder component.
    public static let folder: CGFloat = 14
}

/// Declared on the protocol so `.shelf(Radius.small)` resolves as an implicit member
/// wherever SwiftUI asks for a shape, and `RoundedRectangle.shelf(_:)` still works
/// when a concrete type is needed.
public extension InsettableShape where Self == RoundedRectangle {
    static func shelf(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
