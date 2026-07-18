import SwiftData
import SwiftUI
import ShelfUI

/// Sidebar: smart views, then the user's categories.
///
/// Rows draw their own selection. The system source list highlight is painted with
/// `selectedContentBackgroundColor`, a solid accent that cannot be softened through
/// `.tint`, so a light fill means owning the row background. Arrow key navigation is
/// handled explicitly here to make up for what the selection binding would give.
struct LibrarySidebar: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]
    @Query private var assets: [Asset]

    @FocusState private var listFocused: Bool

    private var actions: LibraryActions { LibraryActions(context: context, app: app) }

    private var inboxCount: Int {
        assets.count { $0.category == nil }
    }

    /// Flat order used for keyboard navigation.
    private var destinations: [LibrarySelection] {
        [.allItems, .recent, .inbox] + categories.map { .category($0.id) }
    }

    var body: some View {
        List {
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
            }
        }
        .listStyle(.sidebar)
        .contentMargins(.top, Spacing.xs, for: .scrollContent)
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        .onChange(of: app.newCategoryRequested) { _, requested in
            guard requested else { return }
            actions.createCategory()
            app.newCategoryRequested = false
        }
        .navigationTitle("Shelf")
    }

    private func moveSelection(by offset: Int) -> KeyPress.Result {
        let all = destinations
        guard let current = all.firstIndex(of: app.selection) else {
            app.selection = all.first ?? .allItems
            return .handled
        }

        let next = current + offset
        guard all.indices.contains(next) else { return .handled }

        app.selection = all[next]
        return .handled
    }
}

/// One sidebar destination. Owns its selected and hover appearance so the fill can
/// stay light instead of a saturated accent block.
struct SidebarRow: View {
    let title: String
    let symbol: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: symbol)
                    .foregroundStyle(isSelected ? Color.shelfAccent : .secondary)
                    .frame(width: 18)

                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                if let count {
                    Text("\(count)")
                        .font(.shelfNumeric(12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 1)
            .background(SidebarRowBackground(isSelected: isSelected, isHovering: hovering))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: Spacing.s, bottom: 1, trailing: Spacing.s))
        .listRowSeparator(.hidden)
        .onHover { hovering = $0 }
        .shelfAnimation(Motion.snappy, value: hovering)
    }
}

/// Shared so every sidebar row reads identically.
struct SidebarRowBackground: View {
    let isSelected: Bool
    var isHovering: Bool = false
    var isTargeted: Bool = false

    var body: some View {
        RoundedRectangle.shelf(Radius.small)
            .fill(fill)
    }

    private var fill: Color {
        if isTargeted { return .shelfAccent.opacity(0.18) }
        if isSelected { return .shelfSelection }
        if isHovering { return .shelfSelection.opacity(0.45) }
        return .clear
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
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: Spacing.s)

                    Text("\(category.itemCount)")
                        .font(.shelfNumeric(12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 1)
            .background(
                SidebarRowBackground(
                    isSelected: isSelected,
                    isHovering: hovering,
                    isTargeted: isTargeted
                )
            )
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

    private func commitRename() {
        guard isRenaming else { return }
        actions.rename(category, to: category.name)
        app.renamingCategoryID = nil
    }
}
