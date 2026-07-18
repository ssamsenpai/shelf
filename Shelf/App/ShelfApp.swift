import SwiftData
import SwiftUI
import ShelfUI

@main
struct ShelfApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .tint(.shelfAccent)
        }
        .defaultSize(width: 1180, height: 760)
        .modelContainer(for: [ShelfCategory.self, Asset.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Category") { app.newCategoryRequested = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Add Items...") { app.requestImport() }
                    .keyboardShortcut("i", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button("Show Inspector") { app.inspectorPresented.toggle() }
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
                .tint(.shelfAccent)
        }
    }
}
