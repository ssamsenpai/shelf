import SwiftData
import SwiftUI
import ShelfUI

/// The window shell. The sidebar and toolbar get their glass from the system, so
/// nothing here applies a glass effect of its own. Stacking would break it.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @Query private var assets: [Asset]
    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]

    private var actions: LibraryActions { LibraryActions(context: context, app: app) }

    private var selectedAssets: [Asset] {
        assets.filter { app.selectedAssetIDs.contains($0.id) }
    }

    /// New items land in the category being viewed, otherwise in Inbox.
    private var importDestination: ShelfCategory? {
        guard case .category(let id) = app.selection else { return nil }
        return categories.first { $0.id == id }
    }

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
        .shelfAnimation(Motion.smooth, value: app.inspectorPresented)
        .focusedSceneValue(\.libraryActions, actions)
        .onKeyPress(.space) {
            guard let first = selectedAssets.first else { return .ignored }
            actions.quickLook(first)
            return .handled
        }
        .onKeyPress(.return) {
            guard let first = selectedAssets.first else { return .ignored }
            actions.open(first)
            return .handled
        }
        .onKeyPress(.delete) {
            guard !selectedAssets.isEmpty else { return .ignored }
            app.isConfirmingRemoval = true
            return .handled
        }
        .confirmationDialog(
            removalTitle,
            isPresented: $app.isConfirmingRemoval
        ) {
            Button("Remove from Shelf", role: .destructive) {
                actions.remove(selectedAssets)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original files stay where they are.")
        }
        .fileImporter(
            isPresented: $app.isPresentingImport,
            allowedContentTypes: ItemKind.fileBacked.flatMap(\.contentTypes),
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .dropDestination(for: URL.self) { urls, _ in
            Task { await actions.importFiles(urls, into: importDestination) }
            return true
        }
        .alert(
            "Import Failed",
            isPresented: Binding(
                get: { app.importError != nil },
                set: { if !$0 { app.importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { app.importError = nil }
        } message: {
            Text(app.importError ?? "")
        }
    }

    private var removalTitle: String {
        selectedAssets.count == 1
            ? "Remove this item from Shelf?"
            : "Remove \(selectedAssets.count) items from Shelf?"
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await actions.importFiles(urls, into: importDestination) }
        case .failure(let error):
            app.importError = error.localizedDescription
        }
    }
}

/// Lets menu commands reach the library actions of the focused window.
private struct LibraryActionsKey: FocusedValueKey {
    typealias Value = LibraryActions
}

extension FocusedValues {
    var libraryActions: LibraryActions? {
        get { self[LibraryActionsKey.self] }
        set { self[LibraryActionsKey.self] = newValue }
    }
}
