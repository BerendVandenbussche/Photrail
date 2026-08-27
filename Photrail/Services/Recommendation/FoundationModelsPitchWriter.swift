import Foundation
import FoundationModels

/// What the on-device model is asked to return: a choice from the shortlist, and the sentences.
///
/// The choice is a *number*, not a name. A name is something a language model can invent; an
/// index into a list the app built is something it can only get wrong in a way the app can
/// detect and correct. That validation happens in `pitch(shortlist:context:)` below, and is the
/// reason nothing this model emits can put a destination on screen that isn't real.
@available(iOS 26.0, *)
@Generable
private struct GeneratedPitch {
    @Guide(description: "The number of the destination you chose, exactly as it appears in the list.")
    let choice: Int
    @Guide(description: "Two short sentences on why this traveller in particular would like it.")
    let reason: String
}

/// Writes the pitch with Apple's on-device foundation model.
///
/// Requires Apple Intelligence: iPhone 15 Pro and later, an Apple Silicon Mac, or the Simulator
/// hosted on one. Everywhere else `isAvailable` is false and `TripPitchWriterFactory` never
/// constructs this type. Nothing here reaches the network — the model runs locally, and the
/// prompt is built entirely from data already on the device.
///
/// Every failure path ends at `TemplatePitchWriter` rather than at an error state. The card is
/// showing a destination the app chose from measured data; if the prose can't be generated, the
/// only thing lost is the prose.
@available(iOS 26.0, *)
struct FoundationModelsPitchWriter: TripPitchWriter {

    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func pitch(shortlist: [RankedDestination], context: TripSuggestionContext) async -> TripPitch {
        let fallback = TemplatePitchWriter()
        guard !shortlist.isEmpty else {
            return await fallback.pitch(shortlist: shortlist, context: context)
        }

        let model = SystemLanguageModel.default
        let language = Locale.Language(identifier: context.languageIdentifier)
        // Apple Intelligence ships a subset of languages, and generating English prose under a
        // Dutch UI would look worse than the translated template does.
        guard case .available = model.availability,
              model.supportedLanguages.contains(where: { $0.isEquivalent(to: language) })
        else {
            return await fallback.pitch(shortlist: shortlist, context: context)
        }

        do {
            let session = LanguageModelSession(instructions: Self.instructions(for: context))
            let reply = try await session.respond(
                to: Self.prompt(shortlist: shortlist, context: context),
                generating: GeneratedPitch.self,
                options: GenerationOptions(temperature: 0.7, maximumResponseTokens: 220))

            let text = reply.content.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return await fallback.pitch(shortlist: shortlist, context: context)
            }
            // The list is presented 1-based because that is how it reads in the prompt.
            // Anything outside it falls back to the app's own top pick.
            let zeroBased = reply.content.choice - 1
            let index = shortlist.indices.contains(zeroBased) ? zeroBased : 0
            return TripPitch(index: index, text: text, generatedByModel: true)
        } catch {
            // Deliberately blanket: every `LanguageModelSession.GenerationError` case —
            // assets unavailable, guardrail violation, context window, rate limiting, refusal,
            // decoding failure — has the same right answer here, and so does anything new
            // Apple adds to that enum later.
            return await fallback.pitch(shortlist: shortlist, context: context)
        }
    }

    // MARK: - Prompting

    private static func instructions(for context: TripSuggestionContext) -> String {
        // Named in English so the instruction reads naturally to the model regardless of the
        // language it is being asked to write in.
        let languageName = Locale(identifier: "en")
            .localizedString(forLanguageCode: context.languageIdentifier) ?? "English"
        return """
        You help someone choose their next trip.

        You are given a numbered shortlist of real destinations that have already been selected \
        for this person, and a summary of where they have travelled. Choose exactly one entry \
        from the list and say why it suits them.

        Rules:
        - Only name places that appear in the list or in the summary. Never name any other place.
        - Never say they have been somewhere the summary does not mention.
        - Do not invent details about a destination: no prices, no seasons, no travel times, \
        no claims about what it is like there beyond what the list says.
        - Write in \(languageName). Two short sentences, warm and plain. \
        No exclamation marks and no emoji.
        """
    }

    private static func prompt(shortlist: [RankedDestination],
                               context: TripSuggestionContext) -> String {
        var lines: [String] = ["This traveller:"]

        if let dominant = context.dominant {
            lines.append("- Travel style: \(dominant.englishTitle)")
        }
        if !context.topCategories.isEmpty {
            let shares = context.topCategories
                .map { "\($0.category.englishTitle) \(Int($0.percentage.rounded()))%" }
                .joined(separator: ", ")
            lines.append("- Style mix: \(shares)")
        }
        lines.append("- Countries visited: \(context.countryCount)")
        if !context.recentCountryNames.isEmpty {
            lines.append("- Recently visited: \(context.recentCountryNames.joined(separator: ", "))")
        }
        if !context.seenWonderNames.isEmpty {
            lines.append("- Landmarks they have already photographed: \(context.seenWonderNames.joined(separator: ", "))")
        }

        lines.append("")
        lines.append("Shortlist:")
        for (offset, entry) in shortlist.enumerated() {
            let destination = entry.candidate
            var line = "\(offset + 1). \(destination.name)"
            if !destination.isWonder || destination.countryCode != destination.name {
                line += " (\(CountryCatalog.name(for: destination.countryCode)))"
            }
            line += " — \(Int((entry.match * 100).rounded()))% style match"
            if !destination.isWonder, !destination.highlights.isEmpty {
                line += "; notable places: \(destination.highlights.joined(separator: ", "))"
            }
            lines.append(line)
        }

        lines.append("")
        lines.append("Choose one and write the two sentences.")
        return lines.joined(separator: "\n")
    }
}
