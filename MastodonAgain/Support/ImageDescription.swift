import CoreGraphics
import Vision

// USAGE:
// let altText = ImageDescription(image: someCGImage).descriptiveText

// TODO:
// - Localization. Currently we only produce English descriptions
// - Interface to categories, search terms, found text, etc.
// - Options to query classification, text, animals (?), objects, attention areas, etc.
// - Probably hang this off an extension for Image, UIImage, NSImage.

struct ImageDescription {
    init(image: CGImage) {
        terms = Self.determineTerms(from: image)
    }

    var descriptiveText: String {
        terms.descriptiveText
    }

    // MARK: - Internal

    private var terms: AssociatedTerms

    private static func determineTerms(from image: CGImage) -> AssociatedTerms {
        var terms = AssociatedTerms()
        // Classify the images
        let handler = VNImageRequestHandler(cgImage: image)
        let classifyRequest = VNClassifyImageRequest()
        let textRequest = VNRecognizeTextRequest()
        try? handler.perform([classifyRequest, textRequest])

        // Categories & Search Terms
        if let classifyObservations = classifyRequest.results {
            terms.categories = classifyObservations
                .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
                .reduce(into: [String: VNConfidence]()) { dict, observation in dict[observation.identifier] = observation.confidence }

            terms.searchTerms = classifyObservations
                .filter { $0.hasMinimumPrecision(0.01, forRecall: 0.7) }
                .reduce(into: [String: VNConfidence]()) { dict, observation in dict[observation.identifier] = observation.confidence }
        }

        // Text found in image
        terms.foundText = textRequest.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")

        return terms
    }

    // MARK: - AssociatedTerms holds the various categories, search keywords, text, etc

    private struct AssociatedTerms {
        var foundText: String?
        var categories = [String: VNConfidence]()
        var searchTerms = [String: VNConfidence]()

        var descriptiveText: String {
            // Start with the top three categories...
            var contentsText = categories
                .sorted(by: { $0.value > $1.value })
                .prefix(3)
                .compactMap { formatted(term: $0.0) }
                .joined(separator: ", ")
            // ... failing that we'll try using the search terms...
            if contentsText.isEmpty {
                contentsText = searchTerms
                    .sorted(by: { $0.value > $1.value })
                    .prefix(3)
                    .compactMap { formatted(term: $0.0) }
                    .joined(separator: ", ")
            }
            // ... if we found any text in the image we'll add it here...
            if let foundText, foundText.isEmpty == false {
                if contentsText.isEmpty == false { contentsText += " and text reading " }
                contentsText += "\"\(foundText)\""
            }
            // ... form the final descriptive string
            if contentsText.isEmpty { contentsText = "nothing obvious" }
            let text = "Shows \(contentsText)."
            print(text)
            return text
        }

        private func formatted(term: String) -> String {
            switch term {
            case "adult": // replace "adult" with Person because "Adult" may be confused as NSFW
                return "person"
            default:
                return term.replacingOccurrences(of: "_", with: " ")
            }
        }
    }
}
