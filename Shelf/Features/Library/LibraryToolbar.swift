import SwiftUI
import ShelfUI

/// The window toolbar. macOS 26 renders toolbar items on glass and merges
/// neighbours into clusters already, so nothing here applies glass of its own.
/// `ToolbarSpacer` is what separates one cluster from the next.
///
/// The builder allows at most ten entries, so sort and the size slider share one
/// group. Fixed spacers guard the separations that must survive narrow widths,
/// the one flexible spacer pushes search and the inspector to the trailing edge.
struct LibraryToolbar: ToolbarContent {
    @Environment(AppState.self) private var app

    var body: some ToolbarContent {
        @Bindable var app = app

        ToolbarItemGroup {
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
                    .foregroundStyle(.secondary)
            }
            // Quiet chrome: the window tint would otherwise paint this accent.
            .tint(Color.secondary)
            .help("Sort items")

            if app.viewMode != .list {
                Slider(value: $app.gridSize, in: 96...220)
                    .frame(width: 90)
                    .help("Preview size")
            }
        }

        ToolbarSpacer(.fixed)

        ToolbarItem {
            Button {
                app.newCategoryRequested = true
            } label: {
                Label("New Collection", systemImage: "folder.badge.plus")
            }
            .help("New collection")
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup {
            Menu {
                Button("Add Files") { app.requestImport() }
                Button("Add Dev Project") { app.filePickerRequest = .projects }
                Button("Add Link") { app.isPresentingAddLink = true }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add files or a link")
        }

        ToolbarSpacer(.flexible)

        // A compact field rather than .searchable, whose macOS toolbar version
        // offers no control over its width.
        ToolbarItem {
            SearchField(text: $app.searchText, prompt: "Search", bare: true)
                .frame(width: 190)
                .padding(.horizontal, Spacing.s)
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
