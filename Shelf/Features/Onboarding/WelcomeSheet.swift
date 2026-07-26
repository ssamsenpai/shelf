import AppKit
import SwiftUI
import ShelfUI

/// First run, three steps, each one an action: fill the library from a folder,
/// set up saving from the browser and Finder, learn the one shortcut. Every step
/// can be skipped, and the whole thing reruns from Help.
struct WelcomeSheet: View {
    let actions: LibraryActions

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0

    // Step 1: the folder scan.
    @State private var scanning = false
    @State private var importing = false
    @State private var found: [URL] = []
    @State private var foundSummary: String?
    @State private var importedCount: Int?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: fillStep
                case 1: saveStep
                default: shortcutStep
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.xl)

            Divider()

            footer
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.l)
        }
        .frame(width: 520)
        .shelfAnimation(Motion.snappy, value: step)
    }

    // MARK: Step 1, fill the shelf

    private var fillStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header(
            symbol: "square.and.arrow.down.on.square",
                title: "Fill your shelf",
                subtitle: "Point Shelf at a folder where your material lives. Images, fonts, videos, and design files are added by reference. Nothing is moved or copied."
            )

            HStack(spacing: Spacing.m) {
                Button("Choose a Folder...") { pickFolder(startingAt: nil) }
                    .buttonStyle(.shelfPrimary)
                Button("Downloads") { pickFolder(startingAt: .downloadsDirectory) }
                    .buttonStyle(.shelfSecondary)
                Button("Desktop") { pickFolder(startingAt: .desktopDirectory) }
                    .buttonStyle(.shelfSecondary)
            }

            if scanning {
                HStack(spacing: Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Looking for material...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if let importedCount {
                Label("\(importedCount) items on your shelf.", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.shelfAccent)
            } else if let foundSummary {
                HStack(spacing: Spacing.m) {
                    Text(foundSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !found.isEmpty {
                        Button {
                            importFound()
                        } label: {
                            if importing {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Add \(found.count) Items")
                            }
                        }
                        .buttonStyle(.shelfPrimary)
                        .disabled(importing)
                    }
                }
            } else {
                Text("You can also drag files into the window at any time.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Step 2, save from anywhere

    private var saveStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header(
                symbol: "cursorarrow.click.2",
                title: "Save from anywhere",
                subtitle: "Shelf catches things where you find them, no window switching."
            )

            VStack(alignment: .leading, spacing: Spacing.m) {
                bullet(symbol: "globe", text: "Right click any image on the web and pick Add to My Shelf. Works in Safari, Chrome, and Arc.")
                bullet(symbol: "folder", text: "Right click any file in Finder and pick Add to My Shelf.")
            }

            Button("Set Up Browser Extension...") {
                // One sheet at a time: close the wizard, then open the guide.
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    app.isPresentingExtensionOnboarding = true
                }
            }
            .buttonStyle(.shelfSecondary)

            Text("You can set this up later from the Help menu.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Step 3, the shortcut

    private var shortcutStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header(
                symbol: "sparkle.magnifyingglass",
                title: "One shortcut to remember",
                subtitle: "From any app, Quick Shelf searches your whole library. Copy an item, or drag it straight into your work."
            )

            HStack(spacing: Spacing.s) {
                keycap("⌥")
                Text("+").foregroundStyle(.tertiary)
                keycap("space")
            }

            Button("Try It Now") {
                QuickShelfController.shared.show()
            }
            .buttonStyle(.shelfPrimary)
        }
    }

    // MARK: Chrome

    private var footer: some View {
        HStack {
            HStack(spacing: Spacing.s) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.shelfAccent : Color.shelfWell)
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if step < 2 {
                Button("Skip") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Button("Continue") { step += 1 }
                    .buttonStyle(.shelfPrimary)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Start Using Shelf") { dismiss() }
                    .buttonStyle(.shelfPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func header(symbol: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.shelfAccent)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func keycap(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, Spacing.m)
            .frame(height: 34)
            .background(Color.shelfWell, in: RoundedRectangle.shelf(Radius.small))
    }

    // MARK: Folder scan

    private func pickFolder(startingAt directory: FileManager.SearchPathDirectory?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        if let directory {
            panel.directoryURL = FileManager.default.urls(for: directory, in: .userDomainMask).first
        }

        guard panel.runModal() == .OK, let folder = panel.url else { return }

        scanning = true
        importedCount = nil
        Task {
            let matches = await Task.detached { Self.scan(folder) }.value
            found = matches
            foundSummary = Self.summary(for: matches)
            scanning = false
        }
    }

    private func importFound() {
        importing = true
        Task {
            let created = await actions.importFiles(found, into: nil)
            importedCount = created.count
            importing = false
            found = []
            foundSummary = nil
        }
    }

    /// Walks the folder for supported kinds. Dependency and build directories are
    /// skipped, and the scan caps out well before it could bog anything down.
    private nonisolated static func scan(_ root: URL) -> [URL] {
        let skipped: Set<String> = [
            "node_modules", "Pods", "DerivedData", "vendor", "dist", "build", ".build"
        ]
        let cap = 500

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .contentTypeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var matches: [URL] = []
        for case let url as URL in enumerator {
            if matches.count >= cap { break }

            guard let values = try? url.resourceValues(
                forKeys: [.isRegularFileKey, .isDirectoryKey, .contentTypeKey]
            ) else { continue }

            if values.isDirectory == true {
                if skipped.contains(url.lastPathComponent) { enumerator.skipDescendants() }
                continue
            }

            guard values.isRegularFile == true,
                  !ImportExclusions.excludes(url),
                  let type = values.contentType,
                  ItemKind.matching(type) != nil
            else { continue }

            matches.append(url)
        }
        return matches
    }

    private nonisolated static func summary(for urls: [URL]) -> String {
        guard !urls.isEmpty else { return "Nothing Shelf collects in that folder. Try another one." }

        var counts: [String: Int] = [:]
        for url in urls {
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                  let kind = ItemKind.matching(type)
            else { continue }
            counts[kind.title, default: 0] += 1
        }

        let parts = counts
            .sorted { $0.value > $1.value }
            .map { "\($0.value) \($0.key.lowercased())" }
        return "Found " + parts.joined(separator: ", ") + "."
    }
}
