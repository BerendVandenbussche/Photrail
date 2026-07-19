import Foundation

/// Value types describing the individual HealthKit-derived insights for a trip.
/// All are `Codable`/`Sendable` so `TripInsights` can be cached in `TripInsightsStore`.
/// Display strings are derived in the views from stable keys, so the cache stays
/// language-neutral (and survives the user switching languages).

// MARK: - 1. Excitement Meter

/// Heart rate captured around the moment a single photo was taken.
struct ExcitementSample: Codable, Sendable, Identifiable {
    let photoID: String
    let bpm: Double
    /// 0…1 position of this photo's bpm within the trip's heart-rate range.
    let vibe: Double
    var id: String { photoID }

    /// A light badge for the photo, from calmest to most thrilling.
    var badge: (emoji: String, labelKey: String) {
        switch vibe {
        case ..<0.25:  return ("😌", "Calm")
        case ..<0.5:   return ("🙂", "Relaxed")
        case ..<0.75:  return ("😃", "Excited")
        default:       return ("🤩", "Thrilling")
        }
    }
}

// MARK: - 2. Vertical Exploration

/// A fun landmark comparison for the total vertical climbed on a trip.
struct ElevationMilestone: Codable, Sendable {
    /// Proper-noun landmark name (language-neutral), e.g. "Eiffel Tower".
    let landmarkName: String
    let emoji: String
    /// Height of one landmark in meters.
    let referenceMeters: Double
    /// How many times the landmark's height was climbed (e.g. 1.4).
    let multiple: Double
}

// MARK: - 3. Travel Fuel

/// Active energy expressed as a count of a locally-themed food.
struct FoodEquivalent: Codable, Sendable {
    /// Stable catalog key (e.g. "croissant"); localized for display in the view.
    let foodKey: String
    let emoji: String
    let count: Int
    let kcalEach: Double
}

// MARK: - 4. Workout Chapters

/// A workout whose time window overlaps the trip, with the photos taken during it.
struct WorkoutChapter: Codable, Sendable, Identifiable {
    let id: String            // HKWorkout UUID string
    /// Stable activity key (e.g. "running", "cycling", "hiking", "walking", "other").
    let activityKey: String
    let emoji: String
    let start: Date
    let end: Date
    let distanceMeters: Double?
    let activeEnergyKcal: Double?
    /// GPS route points from HKWorkoutRoute, in order (empty if none — common for
    /// third-party writes like Strava).
    let route: [GeoPhoto.Coordinate]
    /// Photos taken within the workout's time window.
    let photoIDs: [String]

    var hasRoute: Bool { !route.isEmpty }

    /// Duration formatted as "1h 12m" / "34m".
    var durationText: String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
}

// MARK: - 5. Travel Persona

/// A travel archetype inferred from steps/movement vs. photo volume.
struct TravelPersona: Codable, Sendable {
    /// Stable archetype key: "flaneur", "mission", "explorer", "balanced".
    let archetypeKey: String
    let emoji: String
    let steps: Int
    /// Photos taken per 1,000 steps — the signal separating the archetypes.
    let photosPerThousandSteps: Double

    var titleKey: String {
        switch archetypeKey {
        case "flaneur":  return "The Flâneur"
        case "mission":  return "The Mission Traveler"
        case "explorer": return "The Explorer"
        default:         return "The Balanced Traveler"
        }
    }

    var blurbKey: String {
        switch archetypeKey {
        case "flaneur":  return "You stop constantly — every corner is a photo."
        case "mission":  return "You cover serious ground between shots."
        case "explorer": return "Lots of steps and lots of photos — always on the move."
        default:         return "A steady balance of walking and snapping."
        }
    }
}
