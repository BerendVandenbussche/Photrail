import Foundation

/// The trip the user moved the most on, with the components that decided it.
///
/// Ranked on a blend rather than any single number: steps alone under-credit a cycling or
/// diving trip, calories alone are missing entirely on trips that predate a Watch, and floors
/// alone just duplicates the "Most climbed" card. Every part is a trip *total* — see
/// `AppViewModel.activityScore`.
///
/// Only the trip *id* is stored, never the `Trip` itself: a rescan rebuilds every trip from
/// scratch, so a cached value object would quietly outlive the thing it describes.
struct TripActivityRecord: Codable, Equatable, Sendable {
    let tripID: String
    let steps: Int
    let flights: Int
    let kcal: Int
    let workoutMinutes: Int
    let workoutCount: Int
}

/// One winner from the Health sweep: the trip that topped some measure, and the number that won it.
///
/// Only the trip *id* is stored, never the `Trip` itself: a rescan rebuilds every trip from
/// scratch, so a cached value object would quietly outlive the thing it describes. The id is
/// resolved against the current trips at read time and simply finds nothing if the trip is gone.
struct TripSuperlativeRecord: Codable, Equatable, Sendable {
    let tripID: String
    /// Whatever the measure counts — steps a day, floors a day. The key it is stored under says
    /// which; the record itself deliberately does not care.
    let value: Int
}

/// Caches the Health-sweep superlatives, mirroring `TripInsightsStore`/`TripNameStore`.
///
/// These are single small structs rather than per-trip blob dictionaries, so `UserDefaults` is
/// the right home for them — unlike `TripInsights`, whose workout routes run to thousands of
/// coordinates. They are written and invalidated in lockstep with the travel personality
/// profile, because every one of them falls out of the same sweep in `recomputePersonality()`.
enum TripSuperlativeStore {
    /// The trip the user moved the most on, blended across every signal the sweep has.
    /// Suffixed because the shape stored here changed after the first release of the card.
    static let mostActive = "mostActiveTripV2"
    /// The trip the user climbed the most floors on.
    static let mostClimbed = "mostClimbedTrip"

    static func load<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Passing `nil` clears the record. The sweep always calls this — turning Health off, or
    /// losing the underlying data, has to take the card down rather than leave yesterday's
    /// answer up.
    static func save<T: Encodable>(_ record: T?, for key: String) {
        guard let record, let data = try? JSONEncoder().encode(record) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
