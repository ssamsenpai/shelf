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

    private var actions: LibraryActions { LibraryActions(context: context, app: app) }

    /// Flat order used for keyboard navigation.
    private var destinations: [LibrarySelection] {
        [.allItems, .recent] + categories.map { .category($0.id) }
    }

    var body: some View {
        List {
            Section {
                SidebarRow(
                    title: "All Items",
                    symbol: "square.grid.2x2",
                    count: assets.count,
                    isSelected: app.selection == .allItems
                ) { app.selection = .allItems }

                SidebarRow(
                    title: "Recent",
                    symbol: "clock",
                    count: nil,
                    isSelected: app.selection == .recent
                ) { app.selection = .recent }
            }

            Section {
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
            } header: {
                SectionHeader("Categories")
            }
        }
        .listStyle(.sidebar)
        .contentMargins(.top, Spacing.xxl, for: .scrollContent)
        .focusable()
        .focusEffectDisabled()
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

/// Quiet uppercase section label.
private struct SectionHeader: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.top, Spacing.s)
    }
}

/// A count in a soft capsule, trailing the row.
private struct CountPill: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.shelfNumeric(12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.07), in: .capsule)
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
            HStack(spacing: Spacing.m) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isSelected ? Color.shelfSidebarActive : .primary)
                    .frame(width: 20, alignment: .center)

                Text(title)
                    .foregroundStyle(isSelected ? Color.shelfSidebarActive : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: Spacing.s)

                if let count {
                    CountPill(count: count)
                }
            }
            .padding(.horizontal, Spacing.s)
            .frame(height: 34)
            .background(SidebarRowBackground(isSelected: isSelected, isHovering: hovering))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
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
        if isSelected { return .primary.opacity(0.08) }
        if isHovering { return .primary.opacity(0.04) }
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
            HStack(spacing: Spacing.m) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isSelected ? Color.shelfSidebarActive : .primary)
                    .frame(width: 20, alignment: .center)

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
                        .truncationMode(.tail)

                    Spacer(minLength: Spacing.s)

                    CountPill(count: category.itemCount)
                }
            }
            .padding(.horizontal, Spacing.s)
            .frame(height: 34)
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
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
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
            Button("Change Icon...") { app.iconPickerCategoryID = category.id }
            Divider()
            Button("Delete", role: .destructive) { actions.delete(category) }
        }
    }

    private func commitRename() {
        guard isRenaming else { return }
        actions.rename(category, to: category.name)
        app.renamingCategoryID = nil
    }
}
