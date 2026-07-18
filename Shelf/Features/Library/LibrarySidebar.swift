import SwiftData
import SwiftUI
import ShelfUI

/// Sidebar: smart views, then the user's categories.
///
/// Rows draw their own selection rather than using the List's selection binding.
/// The system highlight is painted with `selectedContentBackgroundColor`, which
/// follows the system accent and ignores `.tint`, so a soft wash with an accent
/// label is only reachable by owning the row background.
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

        return List {
            Section {
                SidebarRow(
                    title: "All Items",
                    symbol: "square.stack",
                    count: assets.count,
                    isSelected: app.selection == .allItems
                ) { app.selection = .allItems }

                SidebarRow(
                    title: "Recent",
                    symbol: "clock",
                    count: nil,
                    isSelected: app.selection == .recent
                ) { app.selection = .recent }

                SidebarRow(
                    title: "Inbox",
                    symbol: "tray",
                    count: inboxCount,
                    isSelected: app.selection == .inbox
                ) { app.selection = .inbox }
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
                    }
                }

                SidebarRow(
                    title: "New Category",
                    symbol: "plus",
                    count: nil,
                    isSelected: false,
                    isQuiet: true
                ) { actions.createCategory() }
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

/// One sidebar destination. Owns its selected and hover appearance.
struct SidebarRow: View {
    let title: String
    let symbol: String
    let count: Int?
    let isSelected: Bool
    var isQuiet: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: symbol)
                    .foregroundStyle(iconStyle)
                    .frame(width: 18)

                Text(title)
                    .foregroundStyle(labelStyle)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                if let count {
                    Text("\(count)")
                        .font(.shelfNumeric(12))
                        .foregroundStyle(isSelected ? Color.shelfAccent : .secondary)
                }
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 1)
            .background(rowBackground, in: .shelf(Radius.small))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: Spacing.s, bottom: 1, trailing: Spacing.s))
        .listRowSeparator(.hidden)
        .onHover { hovering = $0 }
        .shelfAnimation(Motion.snappy, value: hovering)
    }

    private var rowBackground: Color {
        if isSelected { return .shelfSelection }
        if hovering { return .shelfSelection.opacity(0.4) }
        return .clear
    }

    private var iconStyle: Color {
        isSelected ? .shelfAccent : .secondary
    }

    private var labelStyle: Color {
        if isSelected { return .shelfAccent }
        return isQuiet ? .secondary : .primary
    }
}

/// A category row. Doubles as a drop target so assets can be filed by dragging.
private struct CategorySidebarRow: View {
    @Bindable var category: ShelfCategory
    let actions: LibraryActions

    @Environment(AppState.self) private var app
    @FocusState private var renameFocused: Bool
    @State private var isTargeted = false
    @State private var hovering = false

    private var isRenaming: Bool { app.renamingCategoryID == category.id }
    private var isSelected: Bool { app.selection == .category(category.id) }

    var body: some View {
        Button {
            app.selection = .category(category.id)
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: "folder")
                    .foregroundStyle(isSelected ? Color.shelfAccent : .secondary)
                    .frame(width: 18)

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
                        .foregroundStyle(isSelected ? Color.shelfAccent : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: Spacing.s)

                    Text("\(category.itemCount)")
                        .font(.shelfNumeric(12))
                        .foregroundStyle(isSelected ? Color.shelfAccent : .secondary)
                }
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 1)
            .background(rowBackground, in: .shelf(Radius.small))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: Spacing.s, bottom: 1, trailing: Spacing.s))
        .listRowSeparator(.hidden)
        .onHover { hovering = $0 }
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap(UUID.init(uuidString:))
            actions.move(ids: ids, to: category)
            return !ids.isEmpty
        } isTargeted: { isTargeted = $0 }
        .shelfAnimation(Motion.snappy, value: isTargeted)
        .shelfAnimation(Motion.snappy, value: hovering)
        .contextMenu {
            Button("Rename") { app.renamingCategoryID = category.id }
            Button("Delete", role: .destructive) { actions.delete(category) }
        }
    }

    private var rowBackground: Color {
        if isTargeted { return .shelfAccent.opacity(0.18) }
        if isSelected { return .shelfSelection }
        if hovering { return .shelfSelection.opacity(0.4) }
        return .clear
    }

    private func commitRename() {
        guard isRenaming else { return }
        actions.rename(category, to: category.name)
        app.renamingCategoryID = nil
    }
}
