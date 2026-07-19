import AppKit
import SafariServices

/// Receives the context menu click from the web extension and forwards the image
/// to the app through the shelf:// scheme. Everything else, downloading included,
/// happens in the app: the extension itself touches nothing.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        defer { context.completeRequest(returningItems: nil) }

        guard let item = context.inputItems.first as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any],
              let image = message["url"] as? String, !image.isEmpty
        else { return }

        var components = URLComponents()
        components.scheme = "shelf"
        components.host = "add"
        components.queryItems = [
            URLQueryItem(name: "url", value: image),
            URLQueryItem(name: "page", value: message["page"] as? String),
            URLQueryItem(name: "title", value: message["title"] as? String)
        ]

        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
}
