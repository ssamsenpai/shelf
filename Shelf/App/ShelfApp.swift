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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Folder") { app.requestNewFolder() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Import...") { app.requestImport() }
                    .keyboardShortcut("i", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(app)
                .tint(.shelfAccent)
        }
    }
}
