import Foundation

/// What kind of thing is being suggested. Two shapes only, deliberately: a specific site the
/// user can stand in front of, or a whole country to plan around. Anything narrower ("go to
/// Ghent") would be recommending a place off a population table, which is not a reason to go.
enum DestinationKind: Codable, Sendable, Equatable {
    case wonder(id: String)
    case country(code: String)
}

/// One place the app is prepared to suggest, with everything the pitch and the card need.
///
/// Codable because the whole shortlist is persisted: the ranking is rebuilt only when the
/// user's travel signature changes, so "show me another" has to work from cache on a cold
/// launch without touching the geo datasets again.
struct DestinationCandidate: Codable, Sendable, Equatable, Identifiable {
    let kind: DestinationKind
    /// Localized where it can be — country names come from `Locale`, wonder names are the
    /// catalog's English (they are proper nouns and the catalog has no translations).
    let name: String
    let countryCode: String
    /// The wonder's own icon, or the country's flag.
    let emoji: String
    let latitude: Double
    let longitude: Double
    /// Concrete things to name in the pitch — a country's best-known cities, or the wonder
    /// itself. Gives both the template and the model something real to say.
    let highlights: [String]

    var id: String {
        switch kind {
        case .wonder(let id):   return "w:\(id)"
        case .country(let code): return "c:\(code)"
        }
    }

    var isWonder: Bool {
        if case .wonder = kind { return true }
        return false
    }
}

/// A candidate with its verdict. `match` is the cosine similarity between the destination's
/// style vector and the user's personality (0…1, shown as a percentage); `score` is that
/// match after the reachability adjustment, and is what the ordering is actually on.
struct RankedDestination: Codable, Sendable, Equatable, Identifiable {
    let candidate: DestinationCandidate
    let match: Double
    let score: Double

    var id: String { candidate.id }
}

/// What the Dashboard card renders. Assembled from the persisted shortlist by `AppViewModel`.
struct TripSuggestion: Sendable, Equatable {
    let destination: DestinationCandidate
    let match: Double
    /// Nil while the pitch is still being written — the card shows a placeholder.
    let pitch: String?
    /// True only when an on-device model actually produced `pitch`. Drives the footnote, and
    /// must never be set optimistically: claiming Apple Intelligence wrote a templated
    /// sentence would be a lie printed under the user's own data.
    let generatedByModel: Bool
    /// Whether there is anything else to cycle to.
    let hasAlternatives: Bool
}
