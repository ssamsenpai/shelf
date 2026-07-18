import SwiftUI
import ShelfUI

/// Right pane. Quiet when nothing is selected, compact when something is.
struct InspectorPane: View {
    @Environment(AppState.self) private var app

    var body: some View {
        EmptyState(
            symbol: "sidebar.trailing",
            title: "No Selection",
            message: "Select an item to see its details."
        )
    }
}
