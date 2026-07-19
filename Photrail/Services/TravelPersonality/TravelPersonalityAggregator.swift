import Foundation

/// Aggregates per-photo scores → per-trip → lifetime profile.
///
/// Each trip's score vector is normalized to a unit before being combined, then
/// weighted by `sqrt(photoCount)`. This keeps a 2,000-photo city trip from
/// drowning out a short hike, while still letting bigger trips count for more.
struct TravelPersonalityAggregator: Sendable {

    struct ScoredPhoto: Sendable {
        let id: String
        let scores: TravelCategoryScores
    }

    /// How strongly HealthKit signals may tilt a trip's flavour, relative to its photo
    /// evidence (0 = ignore health, 1 = health can weigh as much as all photos in the trip).
    private static let healthInfluence = 0.5

    func aggregate(_ scored: [ScoredPhoto], trips: [Trip], photoCount: Int,
                   healthDirectionByTrip: [String: TravelCategoryScores] = [:]) -> TravelPersonalityProfile {
        guard !scored.isEmpty else { return .empty }

        // Map each photo to a trip bucket (photos outside any trip share one bucket).
        var tripOfPhoto: [String: String] = [:]
        for trip in trips {
            for id in trip.photoIDs { tripOfPhoto[id] = trip.id }
        }

        var buckets: [String: (scores: TravelCategoryScores, count: Int)] = [:]
        for photo in scored {
            let key = tripOfPhoto[photo.id] ?? "__loose__"
            var bucket = buckets[key] ?? (TravelCategoryScores(), 0)
            bucket.scores = bucket.scores + photo.scores
            bucket.count += 1
            buckets[key] = bucket
        }

        // Combine normalized, dampened trip vectors into a lifetime vector. When the user
        // opted into Insights, a per-trip Health direction tilts that trip's flavour —
        // scaled to the trip's own photo evidence so it shifts proportions, not magnitude.
        var lifetime = TravelCategoryScores()
        for (key, bucket) in buckets {
            var scores = bucket.scores
            if let direction = healthDirectionByTrip[key], direction.total > 0 {
                let bucketTotal = bucket.scores.total
                if bucketTotal > 0 {
                    scores = scores + direction.normalized(to: bucketTotal * Self.healthInfluence)
                }
            }
            let weight = (Double(bucket.count)).squareRoot()
            lifetime = lifetime + scores.normalized(to: weight)
        }

        // Integer percentages that sum to exactly 100 (largest-remainder rounding),
        // so the displayed slices always add up — no 93%/101% rounding drift.
        let rounded = Self.percentagesSummingTo100(lifetime)
        let slices = TravelCategory.allCases
            .map { TravelPersonalityProfile.Slice(category: $0, percentage: Double(rounded[$0] ?? 0)) }
            .sorted { $0.percentage > $1.percentage }

        // How many photos contributed to each category (a non-zero score).
        var counts: [String: Int] = [:]
        for photo in scored {
            for category in TravelCategory.allCases where photo.scores[category] > 0 {
                counts[category.rawValue, default: 0] += 1
            }
        }

        let confidence = min(1, Double(photoCount) / 200)
        return TravelPersonalityProfile(slices: slices, photoCount: photoCount,
                                        confidence: confidence, categoryPhotoCounts: counts)
    }

    /// Convert a raw score vector into whole-number percentages that sum to exactly 100,
    /// using the largest-remainder (Hamilton) method. Returns all-zero when there's no data.
    static func percentagesSummingTo100(_ scores: TravelCategoryScores) -> [TravelCategory: Int] {
        let total = scores.total
        guard total > 0 else {
            return Dictionary(uniqueKeysWithValues: TravelCategory.allCases.map { ($0, 0) })
        }

        var result: [TravelCategory: Int] = [:]
        var remainders: [(category: TravelCategory, remainder: Double)] = []
        var floorSum = 0
        for category in TravelCategory.allCases {
            let scaled = scores[category] / total * 100
            let floor = Int(scaled.rounded(.down))
            result[category] = floor
            floorSum += floor
            remainders.append((category, scaled - Double(floor)))
        }

        // Distribute the leftover points to the largest fractional remainders.
        var deficit = 100 - floorSum
        for entry in remainders.sorted(by: { $0.remainder > $1.remainder }) where deficit > 0 {
            result[entry.category, default: 0] += 1
            deficit -= 1
        }
        return result
    }
}
