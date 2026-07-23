import AppKit
import SwiftData

/// Receives "Add to My Shelf" from Finder's context menu. A macOS Service: the
/// system hands over the selected files on the pasteboard with read access
/// already granted, and they run through the normal import pipeline.
@MainActor
final class ShelfServicesProvider: NSObject {
    static let shared = ShelfServicesProvider()

    /// Attached at launch, same bridge Quick Shelf uses.
    weak var appState: AppState?

    @objc func addToShelf(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty else {
            error.pointee = "No files to add."
            return
        }

        guard let appState else {
            error.pointee = "Shelf is still starting."
            return
        }

        let actions = LibraryActions(context: Store.container.mainContext, app: appState)

        Task { @MainActor in
            let created = await actions.importFiles(urls, into: nil)

            // Land in the app on what was just added.
            if let first = created.first {
                appState.selection = .allItems
                appState.selectedAssetIDs = [first.id]
            }
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

/// The provider has to be registered once AppKit is up, which is later than the
/// SwiftUI App initializer.
final class ShelfAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = ShelfServicesProvider.shared
        NSUpdateDynamicServices()
    }
}
