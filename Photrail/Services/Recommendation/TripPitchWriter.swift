import Foundation

/// One category's share of the profile, for the prompt.
struct CategoryShare: Sendable {
    let category: TravelCategory
    let percentage: Double
}

/// Everything a pitch is allowed to know about the traveller.
///
/// Deliberately narrow: category names, country names, wonder names and counts. No
/// coordinates, no dates, no photo identifiers. Nothing here leaves the device under any
/// implementation, but keeping the context small also keeps the prompt well inside the
/// on-device model's context window, and keeps the set of things it could get wrong small.
struct TripSuggestionContext: Sendable {
    let dominant: TravelCategory?
    let topCategories: [CategoryShare]
    let recentCountryNames: [String]
    let seenWonderNames: [String]
    let countryCount: Int
    /// BCP-47 identifier of the language the pitch should be written in.
    let languageIdentifier: String
}

/// The result of writing a pitch.
struct TripPitch: Sendable {
    /// Which shortlist entry the pitch is about. The caller validates this against the list it
    /// passed in — a writer choosing out of range must never be able to point the card at
    /// something that isn't there.
    let index: Int
    let text: String
    /// True only when a language model produced `text`.
    let generatedByModel: Bool
}

/// Writes the sentence under a suggested destination.
///
/// Two implementations: a template that runs everywhere, and an Apple Intelligence one that
/// runs on eligible hardware. The split exists because the *choice* of destination is already
/// made by `DestinationRanker` from measured data — all a model adds is better prose and, when
/// given the whole shortlist, a judgement call between five options that are all good.
protocol TripPitchWriter: Sendable {
    func pitch(shortlist: [RankedDestination], context: TripSuggestionContext) async -> TripPitch
}

/// Composes the pitch from localized fragments. Always available, on every device, and the
/// fallback for every failure of the model path — so this is what most users will read.
struct TemplatePitchWriter: TripPitchWriter {

    func pitch(shortlist: [RankedDestination], context: TripSuggestionContext) async -> TripPitch {
        guard let entry = shortlist.first else {
            return TripPitch(index: 0, text: "", generatedByModel: false)
        }
        let destination = entry.candidate

        let opening: String
        if let dominant = context.dominant {
            opening = String(format: String(localized: "You travel like a %1$@. %2$@ is that kind of place, and you haven't been yet."),
                             dominant.title, destination.name)
        } else {
            opening = String(format: String(localized: "%@ is a strong match for the way you travel, and you haven't been yet."),
                             destination.name)
        }

        // A wonder's "highlights" is the country it sits in, which reads as a location rather
        // than an itinerary — so the two kinds get different second sentences.
        var sentences = [opening]
        if destination.isWonder {
            let country = CountryCatalog.name(for: destination.countryCode)
            sentences.append(String(format: String(localized: "It's in %@."), country))
        } else if !destination.highlights.isEmpty {
            sentences.append(String(format: String(localized: "Start with %@."),
                                    destination.highlights.formatted(.list(type: .and))))
        }

        return TripPitch(index: 0, text: sentences.joined(separator: " "), generatedByModel: false)
    }
}

/// Picks the writer for this device.
///
/// On anything without Apple Intelligence — which includes every iPhone before the 15 Pro, and
/// the Simulator on an Intel Mac — this returns the template writer and the feature works
/// exactly the same, minus the prose. That is the majority path, not a degraded one.
enum TripPitchWriterFactory {
    static func make() -> any TripPitchWriter {
        if #available(iOS 26.0, *), FoundationModelsPitchWriter.isAvailable {
            return FoundationModelsPitchWriter()
        }
        return TemplatePitchWriter()
    }

    /// Whether an on-device model is ready right now. Used only to decide whether it is worth
    /// showing the "written on your device" framing while the pitch is still being generated.
    static var modelAvailable: Bool {
        if #available(iOS 26.0, *) { return FoundationModelsPitchWriter.isAvailable }
        return false
    }
}
