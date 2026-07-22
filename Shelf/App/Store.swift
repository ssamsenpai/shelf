import SwiftData

/// The one model container. The main window and the Quick Shelf panel both read
/// it, so there is a single source of truth instead of two containers racing on
/// the same store file.
@MainActor
enum Store {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: ShelfCategory.self, Asset.self)
        } catch {
            fatalError("Could not open the library store: \(error)")
        }
    }()
}
