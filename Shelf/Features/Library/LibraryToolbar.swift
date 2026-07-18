import SwiftUI
import ShelfUI

/// The window toolbar. On macOS 26 the system already renders toolbar items on
/// glass and merges neighbours into clusters, so this applies no glass of its own.
/// `ToolbarSpacer` is what separates one glass cluster from the next.
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
                Picker("Sort By", selection: $app.sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort items")
        }

        ToolbarSpacer(.flexible)

        ToolbarItemGroup {
            Button {
                app.requestNewFolder()
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .help("New folder")

            Button {
                app.requestImport()
            } label: {
                Label("Import", systemImage: "plus")
            }
            .help("Import items")
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
