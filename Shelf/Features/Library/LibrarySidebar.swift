import SwiftData
import SwiftUI
import ShelfUI

/// Sidebar: smart views, then the user's categories.
///
/// Selection is the system's. An AppKit source list already draws Finder's two
/// appearances, a solid accent fill while the sidebar holds focus and a soft fill
/// with an accent label once focus moves to the content. Overriding the label color
/// breaks the first of those, so rows set no foreground style of their own.
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

        return List(selection: $app.selection) {
            Section {
                Label("All Items", systemImage: "square.stack")
                    .badge(assets.count)
                    .tag(LibrarySelection.allItems)

                Label("Recent", systemImage: "clock")
                    .tag(LibrarySelection.recent)

                Label("Inbox", systemImage: "tray")
                    .badge(inboxCount)
                    .tag(LibrarySelection.inbox)
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
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .contentMargins(.top, Spacing.xs, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) {
            SearchField(text: $app.searchText, prompt: "Search Shelf")
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.xs)
        }
        .onChange(of: app.newCategoryRequested) { _, requested in
            guard requested else { return }
            actions.createCategory()
            app.newCategoryRequested = false
        }
        .navigationTitle("Shelf")
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

            if isRenaming {
                TextField("Name", text: $category.name)
                    .textFieldStyle(.plain)
                    .focused($renameFocused)
                    .onSubmit { commitRename() }
                    .onChange(of: renameFocused) { _, focused in
                        if !focused { commitRename() }
                    }
                    .task { renameFocused = true }
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
        // Only the drop target draws a fill of its own. Selection stays the system's.
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
