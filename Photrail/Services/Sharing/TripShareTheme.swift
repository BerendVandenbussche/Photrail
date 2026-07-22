import SwiftUI

/// A visual theme for a trip's share card, chosen from the trip's dominant workout activity
/// (via cached `TripInsights`). A ski-heavy trip gets an icy "Ski Trip" treatment, a
/// hiking trip a green one, and so on. Trips without Health access or without workouts
/// fall back to `.standard` — the original branded look — so everyone gets a polished card.
struct TripShareTheme {
    enum Kind: Equatable { case standard, ski, hike, cycle, run, water }

    let kind: Kind
    /// Uppercase badge shown above the headline, e.g. "SKI TRIP" (nil for standard).
    let badge: String?
    let emoji: String?
    let accent: Color
    let gradientTop: Color
    let gradientBottom: Color

    /// The matching trip-type "vibe" pill, or nil for `.standard` (fall back to the
    /// location-inferred `Trip.tripType`). Keeps the pill and the share card in sync.
    var tripTypeOverride: TripType? {
        switch kind {
        case .standard: return nil
        case .ski:      return .ski
        case .hike:     return .hike
        case .cycle:    return .cycling
        case .run:      return .running
        case .water:    return .water
        }
    }

    // MARK: - Decision

    /// The activity theme a workout belongs to (walking is intentionally excluded — it's too
    /// ambient to define a trip). Returns nil for activities that shouldn't drive a theme.
    static func kind(forActivityKey key: String) -> Kind? {
        switch key {
        case "skiing", "snowSports", "snowboarding", "skating": return .ski
        case "hiking", "climbing":                               return .hike
        case "cycling":                                          return .cycle
        case "running":                                          return .run
        case "swimming":                                         return .water
        default:                                                 return nil
        }
    }

    /// Pick a theme from the trip's workouts: the activity category with the most chapters
    /// wins, provided it has at least two sessions (so a single stray workout can't hijack
    /// the card). Ties and sparse data fall back to `.standard`.
    static func decide(trip: Trip, insights: TripInsights?) -> TripShareTheme {
        let chapters = insights?.workoutChapters ?? []
        var counts: [Kind: Int] = [:]
        for chapter in chapters {
            guard let k = kind(forActivityKey: chapter.activityKey) else { continue }
            counts[k, default: 0] += 1
        }
        guard let (best, count) = counts.max(by: { $0.value < $1.value }), count >= 2 else {
            return .standard
        }
        return theme(for: best)
    }

    // MARK: - Palettes

    static let standard = TripShareTheme(
        kind: .standard, badge: nil, emoji: nil,
        accent: Color(red: 0.60, green: 0.55, blue: 1.0),
        gradientTop: Color(red: 0.07, green: 0.09, blue: 0.24),
        gradientBottom: Color(red: 0.22, green: 0.13, blue: 0.42))

    static func theme(for kind: Kind) -> TripShareTheme {
        switch kind {
        case .standard:
            return standard
        case .ski:
            return TripShareTheme(
                kind: .ski, badge: "SKI TRIP", emoji: "⛷️",
                accent: Color(red: 0.62, green: 0.85, blue: 1.0),
                gradientTop: Color(red: 0.05, green: 0.15, blue: 0.34),
                gradientBottom: Color(red: 0.10, green: 0.36, blue: 0.60))
        case .hike:
            return TripShareTheme(
                kind: .hike, badge: "HIKING TRIP", emoji: "🥾",
                accent: Color(red: 0.55, green: 0.88, blue: 0.55),
                gradientTop: Color(red: 0.07, green: 0.20, blue: 0.12),
                gradientBottom: Color(red: 0.16, green: 0.42, blue: 0.22))
        case .cycle:
            return TripShareTheme(
                kind: .cycle, badge: "CYCLING TRIP", emoji: "🚴",
                accent: Color(red: 1.0, green: 0.72, blue: 0.34),
                gradientTop: Color(red: 0.28, green: 0.14, blue: 0.05),
                gradientBottom: Color(red: 0.52, green: 0.30, blue: 0.10))
        case .run:
            return TripShareTheme(
                kind: .run, badge: "RUNNING TRIP", emoji: "🏃",
                accent: Color(red: 1.0, green: 0.58, blue: 0.44),
                gradientTop: Color(red: 0.28, green: 0.08, blue: 0.10),
                gradientBottom: Color(red: 0.52, green: 0.18, blue: 0.22))
        case .water:
            return TripShareTheme(
                kind: .water, badge: "WATER TRIP", emoji: "🏊",
                accent: Color(red: 0.42, green: 0.86, blue: 0.95),
                gradientTop: Color(red: 0.04, green: 0.18, blue: 0.26),
                gradientBottom: Color(red: 0.10, green: 0.40, blue: 0.52))
        }
    }
}
