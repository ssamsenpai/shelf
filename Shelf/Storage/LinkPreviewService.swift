import Foundation

/// Fetches Open Graph metadata for a link.
///
/// This is the only code in Shelf that touches the network, and it refuses to run
/// unless the user has turned link previews on in Settings. With the toggle off,
/// `fetch` returns immediately and nothing leaves the device.
///
/// Fetching happens once per link. The result, art included, lands on disk and the
/// app renders from that cache afterwards, so a link keeps its preview offline and
/// no request is ever repeated for a site that answered. Only a link that could not
/// be reached at all stays eligible for another try.
enum LinkPreviewService {

    static let settingKey = "linkPreviews"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: settingKey)
    }

    struct Preview: Sendable {
        var title: String?
        var imageData: Data?
    }

    /// Distinguishes "the site answered and this is what it has" from "we never
    /// reached it". Callers mark a link as fetched only on `.done`, so an offline
    /// attempt stays retryable while an answered one is never repeated.
    enum Outcome: Sendable {
        case disabled
        case unreachable
        case done(Preview)
    }

    static func fetch(for url: URL) async -> Outcome {
        guard isEnabled else { return .disabled }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return .done(Preview())
        }

        // Video platforms gate their pages behind consent walls and scripts, so
        // scraping shows a logo where the content should be. Their oEmbed APIs
        // return the real title and thumbnail directly.
        if let oembed = await oEmbedPreview(for: url) {
            return .done(oembed)
        }

        guard let html = await fetchHTML(at: url) else { return .unreachable }

        let title = metaContent(in: html, property: "og:title") ?? titleTag(in: html)
        var imageData: Data?

        // Open Graph art first, then declared icons, then the classic favicon
        // location. The icon fallbacks are what keep a plain site from rendering
        // as an empty card.
        if let imageValue = metaContent(in: html, property: "og:image"),
           let imageURL = URL(string: imageValue, relativeTo: url)?.absoluteURL {
            imageData = await fetchImage(at: imageURL)
        }

        if imageData == nil {
            for iconValue in iconCandidates(in: html) {
                guard let iconURL = URL(string: iconValue, relativeTo: url)?.absoluteURL else { continue }
                if let data = await fetchImage(at: iconURL) {
                    imageData = data
                    break
                }
            }
        }

        if imageData == nil, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.path = "/favicon.ico"
            components.query = nil
            if let faviconURL = components.url {
                imageData = await fetchImage(at: faviconURL)
            }
        }

        return .done(Preview(title: title, imageData: imageData))
    }

    // MARK: Source icons

    private static var sourceIconDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Shelf/SourceIcons", directoryHint: .isDirectory)
    }

    /// The site's own mark, fetched once per domain and cached to disk. Returns
    /// the cached bytes offline, and nothing when previews are off and no cache
    /// exists yet.
    static func sourceIcon(forHost host: String) async -> Data? {
        let key = host.replacingOccurrences(of: "/", with: "-")
        let cached = sourceIconDirectory.appending(path: "\(key).icon", directoryHint: .notDirectory)
        if let data = try? Data(contentsOf: cached) { return data }

        guard isEnabled else { return nil }

        for candidate in ["https://\(host)/apple-touch-icon.png", "https://\(host)/favicon.ico"] {
            guard let url = URL(string: candidate),
                  let data = await fetchImage(at: url) else { continue }
            try? FileManager.default.createDirectory(at: sourceIconDirectory, withIntermediateDirectories: true)
            try? data.write(to: cached, options: .atomic)
            return data
        }
        return nil
    }

    // MARK: oEmbed

    /// Title and content thumbnail for platforms with an oEmbed endpoint.
    /// Nil means the URL is not one of them and the generic path should run.
    private static func oEmbedPreview(for url: URL) async -> Preview? {
        guard let host = url.host()?.lowercased() else { return nil }

        var endpoint: URL?
        if host.contains("youtube.com") || host == "youtu.be" {
            endpoint = URL(string:
                "https://www.youtube.com/oembed?format=json&url="
                + (url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
            )
        } else if host.contains("vimeo.com") {
            endpoint = URL(string:
                "https://vimeo.com/api/oembed.json?url="
                + (url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
            )
        }
        guard let endpoint else { return nil }

        struct OEmbed: Decodable {
            let title: String?
            let thumbnail_url: String?
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(OEmbed.self, from: data)
        else { return nil }

        var imageData: Data?
        if let thumbnail = decoded.thumbnail_url.flatMap(URL.init(string:)) {
            // YouTube's maxres art exists for most videos and looks far better
            // than the default thumb. Fall back when it does not.
            if thumbnail.absoluteString.contains("ytimg.com"),
               let upgraded = URL(string: thumbnail.absoluteString
                   .replacingOccurrences(of: "hqdefault", with: "maxresdefault")),
               let best = await fetchImage(at: upgraded) {
                imageData = best
            } else {
                imageData = await fetchImage(at: thumbnail)
            }
        }

        guard decoded.title != nil || imageData != nil else { return nil }
        return Preview(title: decoded.title, imageData: imageData)
    }

    // MARK: Requests

    private static func fetchHTML(at url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // Some sites only emit Open Graph tags for a browser like user agent.
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return String(data: data.prefix(400_000), encoding: .utf8)
            ?? String(data: data.prefix(400_000), encoding: .isoLatin1)
    }

    private static func fetchImage(at url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              !data.isEmpty
        else { return nil }

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

    /// Declared icons, largest flavours first.
    private static func iconCandidates(in html: String) -> [String] {
        let rels = ["apple-touch-icon", "apple-touch-icon-precomposed", "icon", "shortcut icon"]
        var candidates: [String] = []

        for rel in rels {
            let patterns = [
                "<link[^>]+rel=[\"']\(rel)[\"'][^>]*href=[\"']([^\"']+)[\"']",
                "<link[^>]+href=[\"']([^\"']+)[\"'][^>]*rel=[\"']\(rel)[\"']"
            ]
            for pattern in patterns {
                if let value = firstMatch(in: html, pattern: pattern) {
                    candidates.append(decodeEntities(value))
                }
            }
        }
        return candidates
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
