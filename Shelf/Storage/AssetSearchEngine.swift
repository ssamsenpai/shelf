import Foundation
import NaturalLanguage

/// The one search matcher. The main window and the Quick Shelf panel both run
/// queries through this, so a query means the same thing everywhere: names,
/// kinds, formats, link domains, tags, detected labels with synonyms, color
/// names, and hex colors.
final class AssetSearchEngine {

    /// The query plus its nearest word embedding neighbours, cached per query
    /// because neighbours would otherwise be looked up per filtered asset.
    private var cachedExpansion: (query: String, terms: [String]) = ("", [])

    func matches(_ asset: Asset, query rawQuery: String) -> Bool {
        let query = rawQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }

        if asset.name.localizedCaseInsensitiveContains(query)
            || asset.kind.title.localizedCaseInsensitiveContains(query) {
            return true
        }

        // A color name finds everything whose palette contains that color.
        if let colorName = Self.matchedColorName(query) {
            if asset.dominantColors.contains(where: { Self.names(forHex: $0).contains(colorName) }) {
                return true
            }
        }

        // A hex query searches by color: anything whose extracted palette comes
        // near it matches, not just exact bucket hits.
        if let target = Self.rgb(from: query) {
            return asset.dominantColors.contains { hex in
                guard let candidate = Self.rgb(from: hex) else { return false }
                let distance = abs(target.0 - candidate.0)
                    + abs(target.1 - candidate.1)
                    + abs(target.2 - candidate.2)
                return distance < 150
            }
        }

        // The format: "png" finds every PNG, "jpg" also hits jpeg, and so on.
        let ext = asset.fileExtension.lowercased()
        if !ext.isEmpty {
            if ext.contains(query) || query.contains(ext) { return true }
            let aliases: [String: Set<String>] = [
                "jpg": ["jpeg"], "jpeg": ["jpg"],
                "mov": ["video", "movie"], "mp4": ["video", "movie"]
            ]
            if aliases[ext]?.contains(query) == true { return true }
        }

        if asset.isLink, let domain = asset.linkDomain,
           domain.localizedCaseInsensitiveContains(query) {
            return true
        }
        if !asset.tags.isEmpty,
           asset.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
            return true
        }

        // What the classifier saw, expanded with near synonyms so "puppy" still
        // finds images labeled "dog". All of it on device.
        for term in expandedTerms(for: query) {
            if asset.visionLabels.contains(where: { $0.contains(term) }) {
                return true
            }
        }
        return false
    }

    private func expandedTerms(for query: String) -> [String] {
        if cachedExpansion.query == query { return cachedExpansion.terms }

        var terms = [query]
        // Neighbours only make sense for a single word.
        if !query.contains(" "), let embedding = NLEmbedding.wordEmbedding(for: .english) {
            let neighbours = embedding.neighbors(for: query, maximumCount: 6)
                .filter { $0.1 < 1.05 }
                .map { $0.0.lowercased() }
            terms.append(contentsOf: neighbours)
        }

        cachedExpansion = (query, terms)
        return terms
    }

    // MARK: Colors

    private static let colorAliases: [String: String] = [
        "grey": "gray", "violet": "purple", "magenta": "pink", "crimson": "red",
        "maroon": "red", "navy": "blue", "aqua": "cyan", "teal": "cyan",
        "turquoise": "cyan", "lime": "green", "beige": "brown", "tan": "brown",
        "gold": "yellow"
    ]

    private static let colorWords: Set<String> = [
        "red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink",
        "brown", "black", "white", "gray"
    ]

    /// The canonical color the query names, or nil when it is not a color word.
    private static func matchedColorName(_ query: String) -> String? {
        let canonical = colorAliases[query] ?? query
        return colorWords.contains(canonical) ? canonical : nil
    }

    /// Classifies a hex into human color names through hue, saturation, and
    /// brightness. Dark warm hues also count as brown, since that is what people
    /// call them.
    private static func names(forHex hex: String) -> Set<String> {
        guard let (r, g, b) = rgb(from: hex) else { return [] }
        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255

        let maxV = max(rf, gf, bf)
        let minV = min(rf, gf, bf)
        let delta = maxV - minV
        let brightness = maxV
        let saturation = maxV == 0 ? 0 : delta / maxV

        if brightness < 0.16 { return ["black"] }
        if saturation < 0.14 { return brightness > 0.82 ? ["white"] : ["gray"] }

        var hue = 0.0
        if delta > 0 {
            if maxV == rf {
                hue = 60 * ((gf - bf) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxV == gf {
                hue = 60 * ((bf - rf) / delta + 2)
            } else {
                hue = 60 * ((rf - gf) / delta + 4)
            }
            if hue < 0 { hue += 360 }
        }

        var names = Set<String>()
        switch hue {
        case ..<15, 345...: names.insert("red")
        case 15..<45: names.insert("orange")
        case 45..<70: names.insert("yellow")
        case 70..<165: names.insert("green")
        case 165..<200: names.insert("cyan")
        case 200..<256: names.insert("blue")
        case 256..<290: names.insert("purple")
        default: names.insert("pink")
        }

        if hue < 70 || hue >= 345, brightness < 0.6, saturation > 0.25 {
            names.insert("brown")
        }
        return names
    }

    /// Parses #RRGGBB or RRGGBB. Nil for anything that is not a color.
    private static func rgb(from text: String) -> (Int, Int, Int)? {
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, cleaned.allSatisfy(\.isHexDigit),
              let value = UInt32(cleaned, radix: 16)
        else { return nil }
        return (Int((value >> 16) & 0xFF), Int((value >> 8) & 0xFF), Int(value & 0xFF))
    }
}
