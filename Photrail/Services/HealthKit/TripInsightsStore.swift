import Foundation

/// Caches computed `TripInsights` per trip, keyed by the stable trip id — mirroring
/// `TripNoteStore`/`TripNameStore`. HealthKit queries are relatively slow, so we compute
/// once and reuse until the trip's photo set changes (tracked via `signature`).
enum TripInsightsStore {
    private static let key = "tripInsights"

    /// Cached insights for a trip, or nil if never computed. Returns nil if the stored
    /// `signature` no longer matches (the trip's photos changed) so the caller recomputes.
    static func insights(for tripID: String, signature: String) -> TripInsights? {
        guard let blob = blobs()[tripID],
              let decoded = try? JSONDecoder().decode(TripInsights.self, from: blob),
              decoded.signature == signature
        else { return nil }
        return decoded
    }

    static func save(_ insights: TripInsights) {
        guard let data = try? JSONEncoder().encode(insights) else { return }
        var dict = blobs()
        dict[insights.tripID] = data
        UserDefaults.standard.set(dict, forKey: key)
    }

    /// Drop the whole cache — called on reindex, since trip ids/photos may change.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func blobs() -> [String: Data] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Data]) ?? [:]
    }
}
