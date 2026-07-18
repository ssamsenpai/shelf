import SwiftUI
import ShelfUI

/// Sidebar: quick destinations, a search field, the Folders / Tags switch, and the
/// tree. NavigationSplitView gives this column its glass automatically.
struct LibrarySidebar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app

        VStack(spacing: Spacing.s) {
            SearchField(text: $app.searchText, prompt: "Search Shelf")
                .padding(.horizontal, Spacing.s)
                .padding(.top, Spacing.s)

            List(selection: $app.selection) {
                Section {
                    SidebarRow(.home, symbol: "house", title: "Home")
                    SidebarRow(.allItems, symbol: "square.stack", title: "All Items")
                    SidebarRow(.recent, symbol: "clock", title: "Recent")
                    SidebarRow(.inbox, symbol: "tray", title: "Inbox")
                }

                Section {
                    SegmentedTabs(
                        selection: $app.sidebarTab,
                        options: SidebarTab.allCases.map { ($0, $0.title) }
                    )
                    .padding(.vertical, Spacing.xs)
                    .listRowSeparator(.hidden)

                    switch app.sidebarTab {
                    case .folders:
                        Text("No folders yet")
                            .shelfMeta()
                            .padding(.vertical, Spacing.xs)
                    case .tags:
                        Text("No tags yet")
                            .shelfMeta()
                            .padding(.vertical, Spacing.xs)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("Shelf")
    }
}

/// One sidebar destination. Count is optional so quick entries stay quiet.
struct SidebarRow: View {
    private let selection: LibrarySelection
    private let symbol: String
    private let title: String
    private let count: Int?

    init(_ selection: LibrarySelection, symbol: String, title: String, count: Int? = nil) {
        self.selection = selection
        self.symbol = symbol
        self.title = title
        self.count = count
    }

    var body: some View {
        Label(title, systemImage: symbol)
            .badge(count.map { Text("\($0)").font(.shelfNumeric(12)) } ?? Text(""))
            .tag(selection)
    }
}
