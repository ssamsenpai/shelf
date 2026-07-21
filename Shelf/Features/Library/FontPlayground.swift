import AppKit
import CoreText
import SwiftData
import SwiftUI
import ShelfUI

/// Registers collected font files with the process so they can render in app.
/// Access to each file is opened once and held: CoreText reads glyph data lazily,
/// so the scope has to outlive registration.
enum FontRegistry {

    nonisolated(unsafe) private static var registered: [UUID: CTFont] = [:]

    @MainActor
    static func font(for asset: Asset, size: CGFloat) -> Font? {
        if let cached = registered[asset.id] {
            return Font(CTFontCreateCopyWithAttributes(cached, size, nil, nil))
        }

        guard let bookmark = asset.bookmark,
              let url = BookmarkStore.resolveURL(bookmark)
        else { return nil }

        _ = url.startAccessingSecurityScopedResource()

        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
                as? [CTFontDescriptor],
              let descriptor = descriptors.first
        else { return nil }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)

        let ctFont = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        registered[asset.id] = ctFont
        return Font(ctFont)
    }
}

/// Type once, see every collected font render it. A viewer, not an editor.
struct FontPlayground: View {
    @Query private var assets: [Asset]

    @State private var specimen = "The quick brown fox jumps over the lazy dog"
    @State private var size: Double = 28

    private var fonts: [Asset] {
        assets.filter { $0.kind == .font }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Group {
            if fonts.isEmpty {
                EmptyState(
                    symbol: "textformat",
                    title: "No fonts yet",
                    message: "Add font files to your library and they will show up here."
                )
            } else {
                List(fonts) { asset in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(asset.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let font = FontRegistry.font(for: asset, size: size) {
                            Text(specimen.isEmpty ? " " : specimen)
                                .font(font)
                                .lineLimit(2)
                        } else {
                            Text("Could not load this font. The original file may have moved.")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, Spacing.s)
                }
                .listStyle(.inset)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: Spacing.m) {
                TextField("Type something", text: $specimen)
                    .textFieldStyle(.roundedBorder)

                Slider(value: $size, in: 12...72)
                    .frame(width: 140)

                Text("\(Int(size)) pt")
                    .font(.shelfNumeric(12))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(Spacing.m)
            .background(.bar)
        }
        .navigationTitle("Font Playground")
        .frame(minWidth: 480, minHeight: 360)
    }
}
