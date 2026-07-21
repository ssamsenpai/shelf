import SwiftData
import SwiftUI
import ShelfUI

/// The window shell. The sidebar and toolbar get their glass from the system, so
/// nothing here applies a glass effect of its own. Stacking would break it.
///
/// The modifier chain is split into layers because one flat chain of this size is
/// beyond what the type checker will resolve in reasonable time.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @Query private var assets: [Asset]
    @Query(sort: \ShelfCategory.createdAt) private var categories: [ShelfCategory]

    /// Backfill runs when previews turn on, so this tracks the edge, not the level.
    @State private var linkPreviewsWereEnabled = LinkPreviewService.isEnabled

    private var actions: LibraryActions { LibraryActions(context: context, app: app) }

    private var selectedAssets: [Asset] {
        assets.filter { app.selectedAssetIDs.contains($0.id) }
    }

    /// New items land in the category being viewed, otherwise unfiled.
    private var importDestination: ShelfCategory? {
        guard case .category(let id) = app.selection else { return nil }
        return categories.first { $0.id == id }
    }

    var body: some View {
        presenting
    }

    // MARK: Shell

    private var shell: some View {
        @Bindable var app = app

        return NavigationSplitView(columnVisibility: $app.columnVisibility) {
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
    }

    // MARK: Keyboard

    private var interacting: some View {
        @Bindable var app = app

        return shell
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
            .confirmationDialog(removalTitle, isPresented: $app.isConfirmingRemoval) {
                Button("Remove from Shelf", role: .destructive) {
                    actions.remove(selectedAssets)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The original files stay where they are.")
            }
    }

    // MARK: Sheets, import, lifecycle

    private var presenting: some View {
        @Bindable var app = app

        return interacting
            .sheet(isPresented: $app.isPresentingExtensionOnboarding) {
                ExtensionOnboardingSheet()
            }
            .sheet(isPresented: $app.isPresentingAddLink) {
                AddLinkSheet(actions: actions, defaultCategory: importDestination)
            }
            .sheet(
                isPresented: Binding(
                    get: { app.iconPickerCategoryID != nil },
                    set: { if !$0 { app.iconPickerCategoryID = nil } }
                )
            ) {
                if let id = app.iconPickerCategoryID,
                   let category = categories.first(where: { $0.id == id }) {
                    SymbolPickerSheet(category: category, actions: actions)
                }
            }
            .task {
                // The extension walkthrough shows once, then lives in Help.
                let defaults = UserDefaults.standard
                if !defaults.bool(forKey: "didShowExtensionOnboarding") {
                    defaults.set(true, forKey: "didShowExtensionOnboarding")
                    app.isPresentingExtensionOnboarding = true
                }

                actions.seedDefaultCategoriesIfNeeded()
                actions.seedDevProjectsCategoryIfNeeded()
                selectFirstAssetIfNeeded()
                await actions.backfillLinkPreviews()
                await actions.backfillVisionLabels()
            }
            .onChange(of: assets.count) { _, _ in
                selectFirstAssetIfNeeded()
            }
            .onOpenURL { url in
                handleShelfURL(url)
            }
            // UserDefaults is the only channel between the Settings scene and this
            // window, so the toggle flipping on is observed here and art fetches
            // right away instead of waiting for the next launch.
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                let enabled = LinkPreviewService.isEnabled
                guard enabled != linkPreviewsWereEnabled else { return }
                linkPreviewsWereEnabled = enabled
                guard enabled else { return }
                Task { await actions.backfillLinkPreviews() }
            }
            .fileImporter(
                isPresented: Binding(
                    get: { app.filePickerRequest != nil },
                    set: { if !$0 { app.filePickerRequest = nil } }
                ),
                allowedContentTypes: app.filePickerRequest == .projects
                    ? [.folder]
                    : ItemKind.fileBacked.flatMap(\.contentTypes),
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .dropDestination(for: URL.self) { urls, _ in
                Task { _ = await actions.importFiles(urls, into: importDestination) }
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

    // MARK: Helpers

    private var removalTitle: String {
        selectedAssets.count == 1
            ? "Remove this item from Shelf?"
            : "Remove \(selectedAssets.count) items from Shelf?"
    }

    /// Opens on something rather than an empty inspector. Only fills a genuinely
    /// empty selection, so it never fights the user.
    private func selectFirstAssetIfNeeded() {
        guard app.selectedAssetIDs.isEmpty,
              let first = assets.sorted(by: { $0.addedAt > $1.addedAt }).first
        else { return }

        app.selectedAssetIDs = [first.id]
    }

    /// shelf://add?url=...&page=...&title=... from the Safari extension.
    @MainActor
    private func handleShelfURL(_ url: URL) {
        guard url.scheme == "shelf", url.host() == "add",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let imageString = items.first(where: { $0.name == "url" })?.value,
              let imageURL = URL(string: imageString)
        else { return }

        let pageURL = items.first(where: { $0.name == "page" })?.value.flatMap(URL.init(string:))
        let title = items.first(where: { $0.name == "title" })?.value

        Task {
            await actions.addFromWeb(imageURL: imageURL, pageURL: pageURL, title: title)
        }
    }

    @MainActor
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { _ = await actions.importFiles(urls, into: importDestination) }
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
