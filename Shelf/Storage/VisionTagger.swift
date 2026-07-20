import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Labels what is in an image using the system's on device classifier. Zero
/// network, zero bundled model: this is the Vision framework the OS ships with.
///
/// Classification runs on the cached thumbnail, which already exists for every
/// previewable asset including link art, so originals are never touched and
/// offline assets still get labels.
enum VisionTagger {

    /// Kinds whose thumbnails are worth classifying. Fonts and notes would only
    /// produce noise, projects have no preview at all.
    static func supports(_ kind: ItemKind) -> Bool {
        switch kind {
        case .image, .svg, .video, .design, .link: true
        case .font, .note, .palette, .project: false
        }
    }

    /// Top labels for an image, lowercase, human readable. Empty when the
    /// classifier finds nothing it trusts.
    static func labels(for imageData: Data) async -> [String] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return [] }

        let request = ClassifyImageRequest()
        guard let observations = try? await request.perform(on: image) else { return [] }

        // The recall for precision filter is the calibrated way to cut this
        // taxonomy. A raw confidence threshold over rejects rare labels.
        return observations
            .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
            .prefix(12)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ").lowercased() }
    }
}
