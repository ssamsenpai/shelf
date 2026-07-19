import SwiftData
import SwiftUI
import ShelfUI

/// Right pane: a large preview then compact metadata. Quiet when nothing is picked.
struct InspectorPane: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @Query private var assets: [Asset]
    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]

    private var actions: LibraryActions { LibraryActions(context: context, app: app) }

    private var selected: [Asset] {
        assets.filter { app.selectedAssetIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if selected.count == 1, let asset = selected.first {
                detail(for: asset)
            } else if selected.count > 1 {
                multipleSelection
            } else {
                EmptyState(
                    symbol: "sidebar.trailing",
                    title: "No Selection",
                    message: "Select an item to see its details."
                )
            }
        }
    }

    private var multipleSelection: some View {
        VStack(spacing: Spacing.l) {
            Text("\(selected.count) items selected")
                .font(.headline)

            Menu("Move to Category") {
                ForEach(categories) { category in
                    Button(category.name) { actions.move(selected, to: category) }
                }
                Divider()
                Button("No Category") { actions.move(selected, to: nil) }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 180)
        }
        .padding(Spacing.xl)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func detail(for asset: Asset) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                ThumbnailProvider(asset: asset) { loaded in
                    let image = loaded?.image
                    ZStack {
                        RoundedRectangle.shelf(Radius.medium)
                            .fill(Color.shelfWell)
                        if let image {
                            image.resizable().aspectRatio(contentMode: .fit).padding(Spacing.s)
                        } else {
                            TypeBadge(symbol: asset.kind.symbol, kindTitle: asset.kind.title)
                        }
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle.shelf(Radius.medium))
                }

                Text(asset.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .textSelection(.enabled)

                actions(for: asset)

                metadata(for: asset)

                if !asset.dominantColors.isEmpty {
                    section("Colors") {
                        SwatchRow(hexes: asset.dominantColors)
                    }
                }

                section("Category") {
                    Menu(asset.category?.name ?? "No Category") {
                        ForEach(categories) { category in
                            Button(category.name) { actions.move([asset], to: category) }
                        }
                        Divider()
                        Button("No Category") { actions.move([asset], to: nil) }
                    }
                    .menuStyle(.borderlessButton)
                }

                section("Note") {
                    NoteEditor(asset: asset, context: context)
                }

                section("Tags") {
                    TagField(asset: asset, context: context)
                }

                if asset.bookmark != nil, BookmarkStore.resolveURL(asset.bookmark!) == nil {
                    Button("Locate File...") { app.requestImport() }
                        .buttonStyle(.glass)
                }
            }
            .padding(Spacing.l)
        }
    }

    /// Open and copy sit right under the name, where they are easiest to reach.
    /// Neutral rather than accent tinted: these are secondary to the content, and
    /// the window tint would otherwise fill them solid blue.
    private func actions(for asset: Asset) -> some View {
        HStack(spacing: Spacing.s) {
            if asset.isProject {
                Button {
                    actions.openInVSCode(asset)
                } label: {
                    iconLabel("VS Code", image: "VSCodeIcon")
                }
                .help("Open in Visual Studio Code")

                Button {
                    actions.openInClaudeCode(asset)
                } label: {
                    iconLabel("Claude", image: "ClaudeCodeIcon")
                }
                .help("Open in the Claude Code CLI")
            } else {
                Button {
                    actions.open(asset)
                } label: {
                    actionLabel("Open", symbol: "arrow.up.forward.app")
                }
            }

            if !asset.isProject {
                Button {
                    actions.copy(asset)
                } label: {
                    actionLabel("Copy", symbol: "doc.on.doc")
                }
            }

            if !asset.isLink {
                Button {
                    actions.revealInFinder(asset)
                } label: {
                    actionLabel(nil, symbol: "folder")
                }
                .help("Reveal in Finder")
                .accessibilityLabel("Reveal in Finder")
            }
        }
        .buttonStyle(.shelfSecondary)
    }

    /// A bundled app icon beside a short label, matching actionLabel's geometry.
    private func iconLabel(_ title: String, image: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionLabel(_ title: String?, symbol: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
            if let title {
                Text(title)
            }
        }
        .frame(maxWidth: title == nil ? nil : .infinity)
    }

    private func metadata(for asset: Asset) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            row("Kind", asset.isProject ? "Dev Project" : asset.kind.title)
            if asset.isProject {
                if !asset.projectLanguages.isEmpty {
                    row("Languages", asset.projectLanguages.joined(separator: ", "))
                }
                if asset.projectFileCount > 0 {
                    row("Files", "\(asset.projectFileCount)")
                }
                row("Git", asset.projectIsGit ? "Yes" : "No")
            }
            if !asset.fileExtension.isEmpty {
                row("Format", asset.fileExtension.uppercased())
            }
            if let dimensions = asset.dimensionsText {
                row("Dimensions", dimensions)
            }
            if let size = asset.fileSizeText {
                row("Size", size)
            }
            if !asset.isLink, let domain = asset.linkDomain {
                row("Source", domain)
            }
            row("Added", asset.addedAt.formatted(date: .abbreviated, time: .shortened))
            if let modified = asset.contentModifiedAt {
                row("Modified", modified.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.m)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// Inline note. Saves as the user types, no document chrome.
private struct NoteEditor: View {
    @Bindable var asset: Asset
    let context: ModelContext

    var body: some View {
        TextEditor(text: $asset.note)
            .font(.callout)
            .scrollContentBackground(.hidden)
            .frame(height: 70)
            .padding(Spacing.xs)
            .background(Color.shelfWell, in: .shelf(Radius.small))
            .onChange(of: asset.note) { _, _ in try? context.save() }
    }
}

/// Optional labels. Tags live here only, never in navigation.
private struct TagField: View {
    @Bindable var asset: Asset
    let context: ModelContext

    @State private var entry: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if !asset.tags.isEmpty {
                FlowLayout(spacing: Spacing.xs) {
                    ForEach(asset.tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            asset.tags.removeAll { $0 == tag }
                            try? context.save()
                        }
                    }
                }
            }

            TextField("Add a tag", text: $entry)
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(Color.shelfWell, in: .shelf(Radius.small))
                .onSubmit {
                    let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, !asset.tags.contains(trimmed) else { return }
                    asset.tags.append(trimmed)
                    entry = ""
                    try? context.save()
                }
        }
    }
}
