import SwiftUI
import ShelfUI

/// Settings. Link previews is the only switch that can ever touch the network, and
/// it ships off.
struct SettingsView: View {
    @AppStorage("watchDownloads") private var watchDownloads = true
    @AppStorage("linkPreviews") private var linkPreviews = false

    var body: some View {
        TabView {
            Form {
                Section {
                    Toggle("Watch Downloads for new assets", isOn: $watchDownloads)
                } footer: {
                    Text("Shelf checks your Downloads folder on launch. Files stay where they are.")
                        .shelfMeta()
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Library", systemImage: "square.stack") }

            Form {
                Section {
                    Toggle("Fetch link previews", isOn: $linkPreviews)
                } footer: {
                    Text("Off by default. When off, Shelf makes no network requests.")
                        .shelfMeta()
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 480, height: 260)
    }
}
