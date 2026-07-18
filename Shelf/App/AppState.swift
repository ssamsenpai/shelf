import Foundation
import Observation
import SwiftUI

/// What the sidebar is pointing at. Categories are the primary structure, the smart
/// views are the only system entries.
enum LibrarySelection: Hashable, Codable {
    case allItems
    case recent
    case inbox
    case category(UUID)
}

enum ViewMode: String, Hashable, CaseIterable {
    case grid
    case list

    var symbol: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

enum SortField: String, CaseIterable, Identifiable {
    case dateAdded
    case name
    case kind
    case size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateAdded: "Date Added"
        case .name: "Name"
        case .kind: "Kind"
        case .size: "Size"
        }
    }
}

/// UI state for the window. Content lives in SwiftData, not here.
@MainActor
@Observable
final class AppState {
    private let defaults = UserDefaults.standard

    var selection: LibrarySelection = .allItems
    var searchText: String = ""
    var selectedAssetIDs: Set<UUID> = []

    /// Category currently being renamed inline, the way Finder names a new folder.
    var renamingCategoryID: UUID?
    /// Bound to the Quick Look panel, driven by Space.
    var quickLookURL: URL?

    var isPresentingImport: Bool = false
    var isConfirmingRemoval: Bool = false
    var importError: String?
    /// Raised by the toolbar and the menu, handled where a model context exists.
    var newCategoryRequested: Bool = false

    // MARK: Persisted preferences

    var viewMode: ViewMode {
        didSet { defaults.set(viewMode.rawValue, forKey: Keys.viewMode) }
    }

    var sortField: SortField {
        didSet { defaults.set(sortField.rawValue, forKey: Keys.sortField) }
    }

    var sortAscending: Bool {
        didSet { defaults.set(sortAscending, forKey: Keys.sortAscending) }
    }

    var inspectorPresented: Bool {
        didSet { defaults.set(inspectorPresented, forKey: Keys.inspector) }
    }

    var gridSize: Double {
        didSet { defaults.set(gridSize, forKey: Keys.gridSize) }
    }

    private enum Keys {
        static let viewMode = "viewMode"
        static let sortField = "sortField"
        static let sortAscending = "sortAscending"
        static let inspector = "inspectorPresented"
        static let gridSize = "gridSize"
    }

    init() {
        viewMode = ViewMode(rawValue: defaults.string(forKey: Keys.viewMode) ?? "") ?? .grid
        sortField = SortField(rawValue: defaults.string(forKey: Keys.sortField) ?? "") ?? .dateAdded
        sortAscending = defaults.object(forKey: Keys.sortAscending) as? Bool ?? false
        inspectorPresented = defaults.bool(forKey: Keys.inspector)
        gridSize = defaults.object(forKey: Keys.gridSize) as? Double ?? 132
    }

    // MARK: Actions

    func requestImport() { isPresentingImport = true }

    func title(for category: ShelfCategory?) -> String {
        switch selection {
        case .allItems: "All Items"
        case .recent: "Recent"
        case .inbox: "Inbox"
        case .category: category?.name ?? "Category"
        }
    }

    /// Applies search and the current sort to a set of assets.
    func arrange(_ assets: [Asset]) -> [Asset] {
        let filtered = assets.filter { matchesSearch($0) }

        let sorted = filtered.sorted { lhs, rhs in
            switch sortField {
            case .dateAdded: lhs.addedAt < rhs.addedAt
            case .name: lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .kind: lhs.kind.title < rhs.kind.title
            case .size: lhs.fileSize < rhs.fileSize
            }
        }

        return sortAscending ? sorted : sorted.reversed()
    }

    private func matchesSearch(_ asset: Asset) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return asset.name.localizedCaseInsensitiveContains(query)
            || asset.kind.title.localizedCaseInsensitiveContains(query)
    }
}
