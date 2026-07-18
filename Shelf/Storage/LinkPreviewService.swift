import Foundation

/// Fetches Open Graph metadata for a link.
///
/// This is the only code in Shelf that touches the network, and it refuses to run
/// unless the user has turned link previews on in Settings. With the toggle off,
/// `fetch` returns immediately and nothing leaves the device.
enum LinkPreviewService {

    static let settingKey = "linkPreviews"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: settingKey)
    }

    struct Preview: Sendable {
        var title: String?
        var imageData: Data?
    }

    static func fetch(for url: URL) async -> Preview? {
        guard isEnabled else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // Some sites only emit Open Graph tags for a browser like user agent.
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data.prefix(400_000), encoding: .utf8)
                  ?? String(data: data.prefix(400_000), encoding: .isoLatin1)
        else { return nil }

        let title = metaContent(in: html, property: "og:title") ?? titleTag(in: html)
        var imageData: Data?

        if let imageValue = metaContent(in: html, property: "og:image"),
           let imageURL = URL(string: imageValue, relativeTo: url)?.absoluteURL {
            imageData = await fetchImage(at: imageURL)
        }

        guard title != nil || imageData != nil else { return nil }
        return Preview(title: title, imageData: imageData)
    }

    private static func fetchImage(at url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            return nil
        }
        // Guard against a page returning HTML where an image was advertised.
        let type = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard type.hasPrefix("image/") else { return nil }
        return data
    }

    // MARK: Parsing

    /// Pulls `content` out of a meta tag, in either attribute order.
    private static func metaContent(in html: String, property: String) -> String? {
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(property)[\"'][^>]*content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]*(?:property|name)=[\"']\(property)[\"']"
        ]

        for pattern in patterns {
            if let value = firstMatch(in: html, pattern: pattern) {
                return decodeEntities(value)
            }
        }
        return nil
    }

    private static func titleTag(in html: String) -> String? {
        firstMatch(in: html, pattern: "<title[^>]*>([^<]+)</title>").map(decodeEntities)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }

        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
