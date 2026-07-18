import SwiftUI
import ShelfUI

/// The window shell. The sidebar and toolbar get their glass from the system, so
/// nothing here applies a glass effect of its own. Stacking would break it.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app

        NavigationSplitView {
            LibrarySidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            LibraryContentView()
        }
        .inspector(isPresented: $app.inspectorPresented) {
            InspectorPane()
                .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .toolbar {
            LibraryToolbar()
        }
    }
}
