import AppKit
import SwiftData
import SwiftUI
import ShelfUI

/// Copies an asset to the pasteboard: the file plus the image where there is one,
/// so pasting works in Finder and in an editor alike. Shared by the inspector and
/// the Quick Shelf panel.
@MainActor
enum AssetPasteboard {
    static func copy(_ asset: Asset) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if asset.isLink {
            guard let url = asset.linkURL else { return }
            pasteboard.writeObjects([url as NSURL])
            pasteboard.setString(url.absoluteString, forType: .string)
            return
        }

        guard let bookmark = asset.bookmark,
              let url = BookmarkStore.resolveURL(bookmark) else { return }

        let scoped = url.startAccessingSecurityScopedResource()
        var items: [any NSPasteboardWriting] = [url as NSURL]
        if let image = NSImage(contentsOf: url) {
            items.append(image)
        }
        pasteboard.writeObjects(items)

        guard scoped else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            url.stopAccessingSecurityScopedResource()
        }
    }
}

/// The Quick Shelf content: a glass search bar with a short list of results.
/// Summoned over any app, dismissed by Escape or by clicking away. Everything
/// renders on Liquid Glass and animates in like Spotlight.
struct QuickShelfView: View {
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var results: [Asset] = []
    @State private var selectedIndex = 0
    @State private var copiedID: UUID?
    @State private var appeared = false
    @FocusState private var fieldFocused: Bool

    private let engine = AssetSearchEngine()
    private let resultLimit = 7

    var body: some View {
        GlassEffectContainer(spacing: Spacing.s) {
            VStack(spacing: Spacing.s) {
                searchBar

                if !results.isEmpty {
                    resultsList
                }
            }
        }
        .frame(width: 620)
        .scaleEffect(appeared ? 1 : 0.97, anchor: .top)
        .opacity(appeared ? 1 : 0)
        .shelfAnimation(Motion.smooth, value: appeared)
        .shelfAnimation(Motion.snappy, value: results.count)
        .onAppear {
            appeared = true
            fieldFocused = true
            refresh()
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
            refresh()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Pieces

    private var searchBar: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search Shelf", text: $query)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($fieldFocused)
                .onSubmit { copySelectedAndDismiss() }
                .onKeyPress(.downArrow) { move(1) }
                .onKeyPress(.upArrow) { move(-1) }
        }
        .padding(.horizontal, Spacing.l)
        .frame(height: 56)
        .glassEffect(.regular, in: .capsule)
    }

    private var resultsList: some View {
        VStack(spacing: 2) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, asset in
                row(asset, isSelected: index == selectedIndex)
            }
        }
        .padding(Spacing.s)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.large))
    }

    private func row(_ asset: Asset, isSelected: Bool) -> some View {
        HStack(spacing: Spacing.m) {
            ThumbnailProvider(asset: asset) { loaded in
                ZStack {
                    RoundedRectangle.shelf(Radius.small)
                        .fill(Color.shelfWell)
                    if let image = loaded?.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: asset.kind.symbol)
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle.shelf(Radius.small))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(asset.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(asset.isLink ? (asset.linkDomain ?? asset.kind.title) : asset.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.m)

            Button {
                AssetPasteboard.copy(asset)
                copiedID = asset.id
            } label: {
                Image(systemName: copiedID == asset.id ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(copiedID == asset.id ? Color.shelfSidebarActive : .secondary)
                    .frame(width: 26, height: 26)
                    .background(.primary.opacity(0.06), in: .circle)
            }
            .buttonStyle(.plain)
            .help("Copy")
            .task(id: copiedID) {
                guard copiedID != nil else { return }
                try? await Task.sleep(for: .seconds(1.5))
                copiedID = nil
            }
        }
        .padding(.horizontal, Spacing.s)
        .frame(height: 48)
        .background(
            isSelected ? Color.primary.opacity(0.08) : .clear,
            in: .shelf(Radius.small)
        )
        .contentShape(.rect)
        .onTapGesture {
            AssetPasteboard.copy(asset)
            copiedID = asset.id
        }
        .onDrag { dragProvider(for: asset) }
    }

    // MARK: Behavior

    private func refresh() {
        let context = Store.container.mainContext
        var descriptor = FetchDescriptor<Asset>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        descriptor.fetchLimit = 400

        let all = (try? context.fetch(descriptor)) ?? []
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            results = Array(all.prefix(resultLimit))
        } else {
            results = Array(all.filter { engine.matches($0, query: trimmed) }.prefix(resultLimit))
        }
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        guard !results.isEmpty else { return .ignored }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + offset))
        return .handled
    }

    private func copySelectedAndDismiss() {
        guard results.indices.contains(selectedIndex) else { return }
        AssetPasteboard.copy(results[selectedIndex])
        onDismiss()
    }

    /// Drags the real file out, so the receiving app gets the asset itself.
    private func dragProvider(for asset: Asset) -> NSItemProvider {
        if asset.isLink, let url = asset.linkURL {
            return NSItemProvider(object: url as NSURL)
        }
        guard let bookmark = asset.bookmark,
              let url = BookmarkStore.resolveURL(bookmark)
        else { return NSItemProvider(object: asset.displayName as NSString) }

        // The scope stays open for the drag's lifetime. It cannot be closed from
        // here without racing the receiver's copy.
        _ = url.startAccessingSecurityScopedResource()
        return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
    }
}
