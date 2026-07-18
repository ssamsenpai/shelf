import SwiftUI

/// Semantic text styles only, so Dynamic Type and accessibility sizes just work.
public extension Font {
    /// Rounded numerals for counts and badges. The only non default face in the UI.
    static func shelfNumeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

public extension Text {
    /// A short, quiet label. Used for metadata, never for paragraphs.
    func shelfMeta() -> some View {
        self.font(.caption).foregroundStyle(.secondary)
    }
}
