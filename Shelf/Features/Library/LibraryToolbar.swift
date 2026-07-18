import SwiftUI
import ShelfUI

/// The window toolbar. macOS 26 renders toolbar items on glass and merges
/// neighbours into clusters already, so nothing here applies glass of its own.
/// `ToolbarSpacer` is what separates one cluster from the next.
struct LibraryToolbar: ToolbarContent {
    @Environment(AppState.self) private var app

    var body: some ToolbarContent {
        @Bindable var app = app

        ToolbarItemGroup {
            Picker("View", selection: $app.viewMode) {
                Image(systemName: ViewMode.grid.symbol).tag(ViewMode.grid)
                Image(systemName: ViewMode.list.symbol).tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .help("Switch between grid and list")

            Menu {
                Picker("Sort By", selection: $app.sortField) {
                    ForEach(SortField.allCases) { field in
                        Text(field.title).tag(field)
                    }
                }
                .pickerStyle(.inline)

                Divider()

                Picker("Order", selection: $app.sortAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort items")
        }

        if app.viewMode == .grid {
            ToolbarItem {
                Slider(value: $app.gridSize, in: 96...220)
                    .frame(width: 90)
                    .help("Preview size")
            }
        }

        ToolbarSpacer(.flexible)

        ToolbarItemGroup {
            Button {
                app.newCategoryRequested = true
            } label: {
                Label("New Category", systemImage: "folder.badge.plus")
            }
            .help("New category")

            Menu {
                Button("Add Files...") { app.requestImport() }
                Button("Add Link...") { app.isPresentingAddLink = true }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add files or a link")
        }

        ToolbarSpacer(.fixed)

        ToolbarItem {
            Button {
                app.inspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .help("Show or hide the inspector")
        }
    }
}
