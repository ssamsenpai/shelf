import SwiftData
import SwiftUI
import ShelfUI

@main
struct ShelfApp: App {
    @State private var app = AppState()

    init() {
        // Previews are on unless the user turns them off. Each link is fetched
        // once and rendered from cache afterwards, so the app stays offline.
        UserDefaults.standard.register(defaults: [LinkPreviewService.settingKey: true])

        // Quick Shelf: Option Space from anywhere.
        QuickShelfController.shared.install()
    }

    var body: some Scene {
        // A single window scene, not a WindowGroup: Shelf is one library, so there
        // is never a second window. This also removes File > New Window and stops
        // shelf:// events from spawning extra windows.
        Window("Shelf", id: "main") {
            RootView()
                .environment(app)
                .tint(.shelfAccent)
        }
        .defaultSize(width: 1180, height: 760)
        .modelContainer(Store.container)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Collection") { app.newCategoryRequested = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Add Items...") { app.requestImport() }
                    .keyboardShortcut("i", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button("Show Inspector") { app.inspectorPresented.toggle() }
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }
            CommandGroup(after: .help) {
                Button("Set Up Browser Extension...") {
                    app.isPresentingExtensionOnboarding = true
                }
            }
        }

        Settings {
            SettingsView()
                .tint(.shelfAccent)
        }
    }
}
