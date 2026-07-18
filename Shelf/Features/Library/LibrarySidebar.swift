import SwiftData
import SwiftUI
import ShelfUI

/// Sidebar: smart views, then the user's categories. Fully native source list, so
/// selection, contrast, and the glass material are all the system's.
struct LibrarySidebar: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]
    @Query private var assets: [Asset]

    private var actions: LibraryActions { LibraryActions(context: context, app: app) }

    private var inboxCount: Int {
        assets.count { $0.category == nil }
    }

    var body: some View {
        @Bindable var app = app

        List(selection: $app.selection) {
            Section {
                smartRow(.allItems, symbol: "square.stack", title: "All Items", count: assets.count)
                smartRow(.recent, symbol: "clock", title: "Recent", count: nil)
                smartRow(.inbox, symbol: "tray", title: "Inbox", count: inboxCount)
            }

            Section("Categories") {
                if categories.isEmpty {
                    Text("No categories yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(categories) { category in
                        CategorySidebarRow(category: category, actions: actions)
                            .tag(LibrarySelection.category(category.id))
                    }
                }

                Button {
                    actions.createCategory()
                } label: {
                    Label("New Category", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            SearchField(text: $app.searchText, prompt: "Search Shelf")
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.s)
        }
        .onChange(of: app.newCategoryRequested) { _, requested in
            guard requested else { return }
            actions.createCategory()
            app.newCategoryRequested = false
        }
        .navigationTitle("Shelf")
    }

    private func smartRow(
        _ selection: LibrarySelection,
        symbol: String,
        title: String,
        count: Int?
    ) -> some View {
        Label(title, systemImage: symbol)
            .badge(count.map { Text("\($0)").font(.shelfNumeric(12)) })
            .tag(selection)
    }
}

/// A category row. Doubles as a drop target so assets can be filed by dragging.
private struct CategorySidebarRow: View {
    @Bindable var category: ShelfCategory
    let actions: LibraryActions

    @Environment(AppState.self) private var app
    @FocusState private var renameFocused: Bool
    @State private var isTargeted = false

    private var isRenaming: Bool { app.renamingCategoryID == category.id }

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            if isRenaming {
                TextField("Name", text: $category.name)
                    .textFieldStyle(.plain)
                    .focused($renameFocused)
                    .onSubmit { commitRename() }
                    .onChange(of: renameFocused) { _, focused in
                        if !focused { commitRename() }
                    }
                    .task {
                        renameFocused = true
                    }
            } else {
                Text(category.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: Spacing.s)

                Text("\(category.itemCount)")
                    .font(.shelfNumeric(12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
        .background(
            isTargeted ? Color.shelfAccent.opacity(0.18) : .clear,
            in: .shelf(Radius.small)
        )
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap(UUID.init(uuidString:))
            actions.move(ids: ids, to: category)
            return !ids.isEmpty
        } isTargeted: { isTargeted = $0 }
        .shelfAnimation(Motion.snappy, value: isTargeted)
        .contextMenu {
            Button("Rename") { app.renamingCategoryID = category.id }
            Button("Delete", role: .destructive) { actions.delete(category) }
        }
    }

    private func commitRename() {
        guard isRenaming else { return }
        actions.rename(category, to: category.name)
        app.renamingCategoryID = nil
    }
}
