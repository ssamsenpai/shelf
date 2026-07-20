import SwiftUI
import ShelfUI

/// Settings. Link previews is the only switch that can ever touch the network.
/// On by default, fetch once per link, cached from then on.
struct SettingsView: View {
    @AppStorage("watchDownloads") private var watchDownloads = true
    @AppStorage(LinkPreviewService.settingKey) private var linkPreviews = true

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
                    Text("Each link is fetched once and kept cached, so Shelf stays offline afterwards. Turn this off and Shelf makes no network requests at all.")
                        .shelfMeta()
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 480, height: 260)
    }
}
