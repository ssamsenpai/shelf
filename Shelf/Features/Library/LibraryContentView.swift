import SwiftUI
import ShelfUI

/// Content column: a Folders section above a Files section. Both fill in once the
/// data model lands. For now it carries the real chrome and a calm empty state.
struct LibraryContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                EmptyState(
                    symbol: "tray.and.arrow.down",
                    title: "Nothing here yet",
                    message: "Add images, fonts, links, or notes to start your library.",
                    actionTitle: "Import Items",
                    action: { app.requestImport() }
                )
                .frame(minHeight: 420)
            }
            .padding(Spacing.xl)
        }
        .background(Color.shelfContent)
        .navigationTitle(title)
    }

    private var title: String {
        switch app.selection {
        case .home, .none: "Home"
        case .allItems: "All Items"
        case .recent: "Recent"
        case .inbox: "Inbox"
        case .folder: "Folder"
        case .tag: "Tag"
        }
    }
}
