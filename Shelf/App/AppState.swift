import Observation
import SwiftUI

/// What the sidebar is pointing at. Folders and tags arrive with the data model.
enum LibrarySelection: Hashable {
    case home
    case allItems
    case recent
    case inbox
    case folder(UUID)
    case tag(UUID)
}

enum SidebarTab: Hashable, CaseIterable {
    case folders
    case tags

    var title: String {
        switch self {
        case .folders: "Folders"
        case .tags: "Tags"
        }
    }
}

enum ViewMode: Hashable {
    case grid
    case list

    var symbol: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case dateAdded = "Date Added"
    case name = "Name"
    case kind = "Kind"
    case size = "Size"

    var id: String { rawValue }
}

/// UI state for the window. Content lives in SwiftData, not here.
@MainActor
@Observable
final class AppState {
    var selection: LibrarySelection? = .home
    var sidebarTab: SidebarTab = .folders
    var searchText: String = ""
    var viewMode: ViewMode = .grid
    var sortOrder: SortOrder = .dateAdded
    var inspectorPresented: Bool = false

    /// Set by menu commands, observed by the views that own the sheets.
    var isPresentingImport: Bool = false
    var isPresentingNewFolder: Bool = false

    func requestImport() { isPresentingImport = true }
    func requestNewFolder() { isPresentingNewFolder = true }
}
