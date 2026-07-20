import AppKit
import SwiftUI
import ShelfUI

/// Walks the user through enabling the browser extension. Shown once on launch,
/// and again any time from Help. Two paths: Safari, or a Chromium browser.
struct ExtensionOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss

    private enum Browser: String, CaseIterable {
        case safari = "Safari"
        case chromium = "Chrome, Arc, Dia"
    }

    @State private var browser: Browser = .safari
    @State private var pickingExportFolder = false
    @State private var exportNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Add from your browser")
                    .font(.title3.weight(.semibold))
                Text("Right click any image on the web and send it straight into Shelf.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: $browser) {
                ForEach(Browser.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: Spacing.m) {
                switch browser {
                case .safari:
                    step(1, "In Safari, open Settings and go to Developer.")
                    step(2, "Turn on Allow Unsigned Extensions.")
                    step(3, "Go to Extensions and turn on Shelf.")
                    step(4, "Choose Always Allow on Every Website.")
                case .chromium:
                    step(1, "Save the extension folder somewhere easy to find.")
                    step(2, "Open chrome://extensions, or arc://extensions in Arc.")
                    step(3, "Turn on Developer Mode.")
                    step(4, "Click Load Unpacked and pick the saved folder.")
                }
            }

            switch browser {
            case .safari:
                Text("Unsigned extensions reset when Safari quits. This step goes away once Shelf is notarized.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            case .chromium:
                HStack(spacing: Spacing.m) {
                    Button("Save Extension Folder...") {
                        pickingExportFolder = true
                    }
                    .buttonStyle(.shelfSecondary)

                    if let exportNote {
                        Text(exportNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.shelfPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 460)
        .fileImporter(
            isPresented: $pickingExportFolder,
            allowedContentTypes: [.folder]
        ) { result in
            guard case .success(let folder) = result else { return }
            export(to: folder)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Text("\(number)")
                .font(.shelfNumeric(12))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color.shelfWell, in: .circle)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Writes the Chromium extension into the chosen folder and shows it in
    /// Finder, ready for Load Unpacked.
    private func export(to folder: URL) {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let target = folder.appending(path: "Shelf Browser Extension", directoryHint: .isDirectory)

        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try ChromiumExtension.manifest.write(
                to: target.appending(path: "manifest.json"), atomically: true, encoding: .utf8
            )
            try ChromiumExtension.background.write(
                to: target.appending(path: "background.js"), atomically: true, encoding: .utf8
            )
            exportNote = "Saved."
            NSWorkspace.shared.activateFileViewerSelecting([target])
        } catch {
            exportNote = "Could not save there."
        }
    }
}

/// The Chromium extension, embedded so the app can hand it out without shipping a
/// loose folder. Keep in sync with ChromeExtension/ in the repository.
private enum ChromiumExtension {
    static let manifest = """
    {
      "manifest_version": 3,
      "name": "Shelf",
      "version": "1.0",
      "description": "Add images from the web to your Shelf.",
      "background": {
        "service_worker": "background.js"
      },
      "permissions": ["contextMenus"],
      "host_permissions": ["<all_urls>"]
    }
    """

    static let background = """
    // One context menu entry on images, everywhere on the web.
    // Chromium build: hands the image to the Shelf app through the shelf:// scheme,
    // no native messaging host needed.

    chrome.runtime.onInstalled.addListener(() => {
        chrome.contextMenus.create({
            id: "add-to-shelf",
            title: "Add to My Shelf",
            contexts: ["image"]
        });
    });

    chrome.contextMenus.onClicked.addListener((info, tab) => {
        if (info.menuItemId !== "add-to-shelf" || !info.srcUrl) { return; }

        const params = new URLSearchParams({
            url: info.srcUrl,
            page: info.pageUrl || (tab && tab.url) || "",
            title: (tab && tab.title) || ""
        });

        // Navigating the current tab to the custom scheme launches Shelf. The page
        // itself stays put, the navigation is consumed by the protocol handler.
        if (tab && tab.id) {
            chrome.tabs.update(tab.id, { url: "shelf://add?" + params.toString() });
        }
    });
    """
}
