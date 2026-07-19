import Foundation
import CoreLocation

/// Pure, `Sendable` computation: turns raw HealthKit samples + a trip's photos into
/// `TripInsights`. Never touches `HKHealthStore` — all HealthKit access happens in
/// `HealthKitService`, so this stays fully unit-testable without entitlements.
struct TravelInsightsEngine: Sendable {

    /// One flight climbed ≈ 3 meters (Apple's convention for `flightsClimbed`).
    static let metersPerFlight = 3.0

    /// Assemble the full insights object from already-fetched raw inputs.
    /// `authoredPhotoIDs`, when non-nil, restricts the Excitement Meter to photos the user
    /// likely took themselves (see `PhotoAuthorship`) — biometrics shouldn't be attributed
    /// to screenshots or images received from others.
    func build(trip: Trip,
               signature: String,
               authorized: Bool,
               photos: [GeoPhoto],
               heartRate: [HealthKitService.HeartRateSample],
               flightsClimbed: Int?,
               activeEnergyKcal: Double?,
               steps: Int?,
               workouts: [HealthKitService.RawWorkout],
               authoredPhotoIDs: Set<String>? = nil,
               now: Date) -> TripInsights {

        let excitement = excitement(photos: photos, heartRate: heartRate,
                                    authoredPhotoIDs: authoredPhotoIDs)
        let milestone = flightsClimbed.flatMap { elevationMilestone(flights: $0) }
        let food = activeEnergyKcal.flatMap { foodEquivalent(kcal: $0, countryCode: trip.countryCode) }
        let chapters = workoutChapters(workouts: workouts, photos: photos)
        let persona = persona(steps: steps, photoCount: photos.count, trip: trip)

        return TripInsights(
            tripID: trip.id, computedAt: now, signature: signature, authorized: authorized,
            excitement: excitement,
            flightsClimbed: (flightsClimbed ?? 0) > 0 ? flightsClimbed : nil,
            elevationMilestone: milestone,
            activeEnergyKcal: (activeEnergyKcal ?? 0) > 0 ? activeEnergyKcal : nil,
            foodEquivalent: food,
            workoutChapters: chapters,
            persona: persona
        )
    }

    // MARK: - 1. Excitement Meter

    /// Match each photo to the nearest heart-rate sample within ±90s, then normalize each
    /// bpm to a 0…1 "vibe" within the trip's own range. Photos without a nearby sample are
    /// omitted (no zeros). Assumes `heartRate` is ascending by date.
    func excitement(photos: [GeoPhoto],
                    heartRate: [HealthKitService.HeartRateSample],
                    authoredPhotoIDs: Set<String>? = nil,
                    window: TimeInterval = 90) -> [ExcitementSample] {
        guard !heartRate.isEmpty else { return [] }
        let dates = heartRate.map(\.date)

        // Only attribute heart rate to photos the user likely took themselves.
        let candidates = authoredPhotoIDs.map { ids in photos.filter { ids.contains($0.id) } } ?? photos

        var matched: [(photoID: String, bpm: Double)] = []
        for photo in candidates {
            guard let nearest = Self.nearestSample(to: photo.date, in: heartRate, dates: dates,
                                                   window: window) else { continue }
            matched.append((photo.id, nearest.bpm))
        }
        guard !matched.isEmpty else { return [] }

        let bpms = matched.map(\.bpm)
        let lo = bpms.min() ?? 0, hi = bpms.max() ?? 0
        let range = hi - lo
        return matched.map { m in
            let vibe = range > 0 ? (m.bpm - lo) / range : 0.5
            return ExcitementSample(photoID: m.photoID, bpm: m.bpm, vibe: vibe)
        }
    }

    /// Nearest sample to `target` within `window`, via binary search on ascending `dates`.
    private static func nearestSample(to target: Date,
                                      in samples: [HealthKitService.HeartRateSample],
                                      dates: [Date], window: TimeInterval)
        -> HealthKitService.HeartRateSample? {
        guard !samples.isEmpty else { return nil }
        // Binary search for insertion point.
        var low = 0, high = dates.count - 1, insert = dates.count
        while low <= high {
            let mid = (low + high) / 2
            if dates[mid] < target { low = mid + 1 } else { insert = mid; high = mid - 1 }
        }
        var best: HealthKitService.HeartRateSample?
        var bestDelta = window
        for idx in [insert - 1, insert] where idx >= 0 && idx < samples.count {
            let delta = abs(samples[idx].date.timeIntervalSince(target))
            if delta <= bestDelta { bestDelta = delta; best = samples[idx] }
        }
        return best
    }

    // MARK: - 2. Vertical Exploration

    /// Curated landmarks, tallest last, for elevation comparisons.
    private static let landmarks: [(name: String, emoji: String, meters: Double)] = [
        ("Statue of Liberty", "🗽", 93),
        ("Eiffel Tower", "🗼", 330),
        ("Empire State Building", "🏙", 443),
        ("Burj Khalifa", "🏢", 828),
        ("Mount Everest", "🏔", 8849),
    ]

    func elevationMilestone(flights: Int) -> ElevationMilestone? {
        guard flights > 0 else { return nil }
        let meters = Double(flights) * Self.metersPerFlight
        // Tallest landmark you climbed at least once; else the smallest (fractional).
        let landmark = Self.landmarks.last { meters >= $0.meters } ?? Self.landmarks[0]
        let multiple = (meters / landmark.meters * 10).rounded() / 10
        return ElevationMilestone(landmarkName: landmark.name, emoji: landmark.emoji,
                                  referenceMeters: landmark.meters, multiple: multiple)
    }

    // MARK: - 3. Travel Fuel

    /// Locally-themed food per country. `kcalEach` is a rough per-item calorie count.
    private static let foods: [String: (key: String, emoji: String, kcal: Double)] = [
        "FR": ("croissant", "🥐", 230),
        "IT": ("pizza slice", "🍕", 285),
        "JP": ("sushi piece", "🍣", 45),
        "US": ("burger", "🍔", 350),
        "ES": ("tapa", "🍤", 80),
        "BE": ("waffle", "🧇", 290),
        "NL": ("stroopwafel", "🧇", 145),
        "DE": ("pretzel", "🥨", 340),
        "TH": ("pad thai plate", "🍜", 400),
        "MX": ("taco", "🌮", 210),
        "IN": ("samosa", "🥟", 260),
        "GB": ("fish & chips", "🍟", 600),
        "GR": ("gyro", "🥙", 350),
        "CH": ("chocolate bar", "🍫", 230),
        "AT": ("strudel slice", "🥧", 300),
        "PT": ("custard tart", "🥧", 300),
    ]
    private static let defaultFood = (key: "meal", emoji: "🍽", kcal: 500.0)

    func foodEquivalent(kcal: Double, countryCode: String) -> FoodEquivalent? {
        guard kcal > 0 else { return nil }
        let food = Self.foods[countryCode.uppercased()] ?? Self.defaultFood
        let count = max(1, Int((kcal / food.kcal).rounded()))
        return FoodEquivalent(foodKey: food.key, emoji: food.emoji, count: count, kcalEach: food.kcal)
    }

    // MARK: - 4. Workout Chapters

    /// Group photos taken during each workout's window. Chapters with no photos are dropped
    /// (nothing to show); a chapter with no route still renders its stats + sub-album.
    func workoutChapters(workouts: [HealthKitService.RawWorkout], photos: [GeoPhoto]) -> [WorkoutChapter] {
        workouts.compactMap { workout in
            let ids = photos
                .filter { $0.date >= workout.start && $0.date <= workout.end }
                .sorted { $0.date < $1.date }
                .map(\.id)
            guard !ids.isEmpty else { return nil }
            let (key, emoji) = Self.activity(for: workout.activityRawValue)
            return WorkoutChapter(id: workout.id, activityKey: key, emoji: emoji,
                                  start: workout.start, end: workout.end,
                                  distanceMeters: workout.distanceMeters,
                                  activeEnergyKcal: workout.energyKcal,
                                  route: workout.route, photoIDs: ids)
        }
    }

    /// Map `HKWorkoutActivityType` raw values to a stable key + emoji (no HealthKit import).
    static func activity(for rawValue: UInt) -> (key: String, emoji: String) {
        switch rawValue {
        case 37: return ("running", "🏃")
        case 52: return ("walking", "🚶")
        case 13: return ("cycling", "🚴")
        case 24: return ("hiking", "🥾")
        case 46: return ("swimming", "🏊")
        case 63: return ("yoga", "🧘")
        case 3:  return ("climbing", "🧗")   // .climbing
        case 59: return ("snowboarding", "🏂")
        case 19: return ("skiing", "⛷️")      // .downhillSkiing
        default: return ("other", "💪")
        }
    }

    // MARK: - 5. Travel Persona

    func persona(steps: Int?, photoCount: Int, trip: Trip) -> TravelPersona? {
        guard let steps, steps > 0 else { return nil }
        let days = max(1, (Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1)
        let ratio = Double(photoCount) / (Double(steps) / 1000)   // photos per 1,000 steps
        let avgStepsPerDay = Double(steps) / Double(days)

        let key: String
        if avgStepsPerDay >= 12_000 && ratio >= 4 {
            key = "explorer"
        } else if ratio >= 6 {
            key = "flaneur"
        } else if ratio < 2 {
            key = "mission"
        } else {
            key = "balanced"
        }
        let emoji: String
        switch key {
        case "flaneur":  emoji = "🚶‍♀️"
        case "mission":  emoji = "🎯"
        case "explorer": emoji = "🧭"
        default:         emoji = "⚖️"
        }
        return TravelPersona(archetypeKey: key, emoji: emoji, steps: steps,
                             photosPerThousandSteps: (ratio * 10).rounded() / 10)
    }
}
