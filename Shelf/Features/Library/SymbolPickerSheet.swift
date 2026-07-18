import SwiftData
import SwiftUI
import ShelfUI

/// Picks an SF Symbol for a category. A curated set rather than the full catalog,
/// since the system provides no API to enumerate symbols and thousands of tiny
/// glyphs make a worse picker than forty good ones.
struct SymbolPickerSheet: View {
    @Bindable var category: ShelfCategory
    let actions: LibraryActions

    @Environment(\.dismiss) private var dismiss

    /// Grouped loosely by what designers actually collect.
    private static let symbols: [String] = [
        "square.stack", "folder", "tray.full", "archivebox", "shippingbox", "cube",
        "photo", "photo.stack", "camera", "film", "paintpalette", "swatchpalette",
        "paintbrush", "pencil.and.ruler", "wand.and.stars", "sparkles",
        "textformat", "character.book.closed", "doc", "doc.text", "book", "bookmark",
        "link", "globe", "safari", "app", "app.badge", "square.grid.2x2",
        "star", "heart", "flame", "bolt", "leaf", "moon", "sun.max",
        "tag", "lightbulb", "briefcase", "graduationcap", "gamecontroller",
        "keyboard", "desktopcomputer", "iphone", "music.note"
    ]

    private let columns = [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: Spacing.s)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Category Icon")
                .font(.title3.weight(.semibold))

            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.s) {
                    ForEach(Self.symbols, id: \.self) { symbol in
                        symbolCell(symbol)
                    }
                }
            }
            .frame(height: 260)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.shelfPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 380)
    }

    private func symbolCell(_ symbol: String) -> some View {
        let isSelected = category.symbolName == symbol

        return Button {
            actions.setIcon(category, symbol: symbol)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(width: 44, height: 44)
                .background(
                    isSelected ? Color.shelfAccent : Color.shelfWell,
                    in: .shelf(Radius.small)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
