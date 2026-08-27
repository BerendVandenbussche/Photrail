import Foundation

/// The cached "where next?" verdict.
///
/// The whole shortlist is kept, not just the winner, so "show me another" works on a cold
/// launch without re-reading the border and place datasets — and so cycling is stable rather
/// than re-rolling a fresh ranking each tap.
struct StoredTripSuggestion: Codable, Sendable, Equatable {
    var shortlist: [RankedDestination]
    /// Which entry is currently on the card.
    var index: Int
    /// Nil until a pitch has been written for `index`. Cleared whenever `index` moves.
    var pitch: String?
    var generatedByModel: Bool
    /// True once the user has cycled to a specific entry. From then on a model writer is given
    /// only that entry, so "show me another" can't be quietly overruled by the model choosing
    /// its favourite again.
    var pinned: Bool = false
    /// What the ranking was computed from — see `AppViewModel.tripSuggestionSignature`.
    var signature: String

    var current: RankedDestination? {
        shortlist.indices.contains(index) ? shortlist[index] : nil
    }
}

/// One small value in `UserDefaults`, following the same pattern as `TripSuperlativeStore`.
enum TripSuggestionStore {
    static let key = "suggestedTripV1"

    static func load() -> StoredTripSuggestion? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredTripSuggestion.self, from: data)
    }

    /// Passing `nil` clears it. Always called, including when there is no suggestion: a library
    /// that shrinks below the threshold has to take the card down, not leave last week's
    /// answer sitting there.
    static func save(_ suggestion: StoredTripSuggestion?) {
        guard let suggestion, let data = try? JSONEncoder().encode(suggestion) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
