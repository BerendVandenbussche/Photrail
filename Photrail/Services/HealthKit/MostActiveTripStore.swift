import Foundation

/// The trip the user moved the most on, by average steps per day.
///
/// Only the trip *id* is stored, never the `Trip` itself: a rescan rebuilds every trip from
/// scratch, so a cached value object would quietly outlive the thing it describes. The id is
/// resolved against the current trips at read time and simply finds nothing if the trip is gone.
struct MostActiveTripRecord: Codable, Equatable, Sendable {
    let tripID: String
    let averageStepsPerDay: Int
}

/// Caches the "most active trip" verdict, mirroring `TripInsightsStore`/`TripNameStore`.
///
/// This is one small struct rather than a per-trip blob dictionary, so `UserDefaults` is the
/// right home for it — unlike `TripInsights`, whose workout routes run to thousands of
/// coordinates. It is written and invalidated in lockstep with the travel personality profile,
/// because both are produced by the same Health sweep in `recomputePersonality()`.
enum MostActiveTripStore {
    private static let key = "mostActiveTrip"

    static func load() -> MostActiveTripRecord? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MostActiveTripRecord.self, from: data)
    }

    /// Passing `nil` clears the record. The sweep always calls this — turning Health off, or
    /// losing step data, has to take the card down rather than leave yesterday's answer up.
    static func save(_ record: MostActiveTripRecord?) {
        guard let record, let data = try? JSONEncoder().encode(record) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
