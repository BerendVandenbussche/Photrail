import Foundation

/// The computed HealthKit-derived insights for one trip. Cached per `trip.id` in
/// `TripInsightsStore`. Every feature field is independently optional so a trip with,
/// say, heart rate but no workouts still renders the parts it has.
struct TripInsights: Codable, Sendable {
    let tripID: String
    let computedAt: Date
    /// A stable signature of the trip's photo set — lets us skip recompute when unchanged.
    let signature: String
    /// False when the user hasn't granted (or has revoked) Health access. Drives the
    /// opt-in prompt rather than an empty state. HealthKit hides read-denial, so we also
    /// treat "authorized but everything empty" as "no data for these dates".
    let authorized: Bool

    // 1. Excitement Meter — per-photo heart-rate badges (only photos with a nearby sample).
    var excitement: [ExcitementSample]

    // 2. Vertical Exploration
    var flightsClimbed: Int?
    var elevationMilestone: ElevationMilestone?

    // 3. Travel Fuel
    var activeEnergyKcal: Double?
    var foodEquivalent: FoodEquivalent?

    // 4. Workout Chapters
    var workoutChapters: [WorkoutChapter]

    // 5. Travel Persona
    var persona: TravelPersona?

    /// True when there's at least one insight worth showing.
    var hasAnyContent: Bool {
        !excitement.isEmpty
            || flightsClimbed != nil
            || activeEnergyKcal != nil
            || !workoutChapters.isEmpty
            || persona != nil
    }

    /// An "authorized but no data" result for a trip whose dates predate any Health data.
    static func empty(tripID: String, signature: String, authorized: Bool, at now: Date) -> TripInsights {
        TripInsights(tripID: tripID, computedAt: now, signature: signature, authorized: authorized,
                     excitement: [], flightsClimbed: nil, elevationMilestone: nil,
                     activeEnergyKcal: nil, foodEquivalent: nil, workoutChapters: [], persona: nil)
    }
}
