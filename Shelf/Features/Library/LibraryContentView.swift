import QuickLook
import SwiftData
import SwiftUI
import ShelfUI

/// Content column. Routes on the sidebar selection: a browse view leads with the
/// coded folders, a category shows its own name and contents.
struct LibraryContentView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]
    @Query private var allAssets: [Asset]

    private var actions: LibraryActions { LibraryActions(context: context, app: app) }

    /// The category being viewed, when the selection is one.
    private var currentCategory: ShelfCategory? {
        guard case .category(let id) = app.selection else { return nil }
        return categories.first { $0.id == id }
    }

    /// Assets for the current selection, before search and sort.
    private var scopedAssets: [Asset] {
        switch app.selection {
        case .allItems, .recent:
            allAssets
        case .category(let id):
            allAssets.filter { $0.category?.id == id }
        }
    }

    private var assets: [Asset] {
        if case .recent = app.selection {
            // Recent is always newest first, regardless of the sort control.
            return allAssets.sorted { $0.addedAt > $1.addedAt }
        }
        return app.arrange(scopedAssets)
    }

    /// Categories lead the browse views so the user can open one visually.
    private var showsCategoryGrid: Bool {
        if case .allItems = app.selection { return !categories.isEmpty }
        return false
    }

    var body: some View {
        @Bindable var app = app

        return Group {
            if assets.isEmpty && !showsCategoryGrid {
                emptyState
            } else if app.viewMode == .canvas {
                AssetCanvasView(assets: assets, actions: actions)
            } else if app.viewMode == .list {
                // List owns its own scrolling, so it is the root here rather than
                // being nested inside a ScrollView where it would clip.
                AssetListView(
                    assets: assets,
                    actions: actions,
                    categories: showsCategoryGrid ? categories : []
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                        if showsCategoryGrid {
                            CategoryFolderGrid(categories: categories, actions: actions)
                        }

                        if !assets.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.m) {
                                if showsCategoryGrid {
                                    sectionHeader("Files")
                                }
                                AssetGridView(assets: assets, actions: actions)
                            }
                        } else {
                            EmptyState(
                                symbol: "square.dashed",
                                title: "No files yet",
                                message: "Open a category or add items to fill your library.",
                                actionTitle: "Add Items",
                                action: { app.requestImport() }
                            )
                            .frame(minHeight: 260)
                        }
                    }
                    .padding(Spacing.xl)
                    // Clears the scrim and the floating switcher.
                    .padding(.bottom, Spacing.xxl * 3)
                }
            }
        }
        .background(Color.shelfContent)
        // The scrim fades content out beneath the floating switcher. Both sit
        // outside the scroll views so they stay put while content moves.
        .overlay(alignment: .bottom) {
            BottomScrim()
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .bottom) {
            GlassSegmentedControl(
                selection: $app.viewMode,
                options: ViewMode.allCases.map {
                    .init(value: $0, symbol: $0.symbol, title: $0.title)
                }
            )
            .padding(.bottom, Spacing.xl)
        }
        .navigationTitle(app.title(for: currentCategory))
        .quickLookPreview($app.quickLookURL)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var emptyState: some View {
        switch app.selection {
        case .allItems:
            if categories.isEmpty {
                EmptyState(
                    symbol: "tray.and.arrow.down",
                    title: "Welcome to Shelf",
                    message: "Keep images, fonts, links, and notes in one place. Files stay where they are.",
                    actionTitle: "Add Items",
                    hint: "You can also drag files straight in.",
                    action: { app.requestImport() }
                )
            } else {
                EmptyState(
                    symbol: "square.dashed",
                    title: "Nothing here yet",
                    message: "Add your first items to this library.",
                    actionTitle: "Add Items",
                    hint: "You can also drag files straight in.",
                    action: { app.requestImport() }
                )
            }
        case .recent:
            EmptyState(
                symbol: "clock",
                title: "Nothing recent",
                message: "Items you add will show up here, newest first."
            )
        case .category:
            EmptyState(
                symbol: "folder",
                title: "Nothing here yet",
                message: "Add items to this category to get started.",
                actionTitle: "Add Items",
                hint: "You can also drag files straight in.",
                action: { app.requestImport() }
            )
        }
    }
}

/// The coded folders at the top of a browse view.
struct CategoryFolderGrid: View {
    let categories: [ShelfCategory]
    let actions: LibraryActions
    /// The list view supplies its own section header, so it opts out of this one.
    var showsHeader: Bool = true

    @Environment(AppState.self) private var app
    @State private var dropTargetID: UUID?

    private let columns = [GridItem(.adaptive(minimum: 132, maximum: 180), spacing: Spacing.l)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if showsHeader {
                Text("Categories")
                    .font(.headline)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.l) {
                ForEach(categories) { category in
                    CategoryStackTile(
                        category: category,
                        isSelected: app.selection == .category(category.id),
                        isDropTarget: dropTargetID == category.id
                    )
                    .contentShape(.rect)
                    .onTapGesture {
                        app.selection = .category(category.id)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        let ids = items.compactMap(UUID.init(uuidString:))
                        actions.move(ids: ids, to: category)
                        return !ids.isEmpty
                    } isTargeted: { targeted in
                        dropTargetID = targeted ? category.id : nil
                    }
                    .contextMenu {
                        Button("Open") { app.selection = .category(category.id) }
                        Button("Rename") { app.renamingCategoryID = category.id }
                        Divider()
                        Button("Delete", role: .destructive) { actions.delete(category) }
                    }
                }
            }
        }
    }
}
