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

    func aggregate(_ scored: [ScoredPhoto], trips: [Trip], photoCount: Int) -> TravelPersonalityProfile {
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

        // Combine normalized, dampened trip vectors into a lifetime vector.
        var lifetime = TravelCategoryScores()
        for bucket in buckets.values {
            let weight = (Double(bucket.count)).squareRoot()
            lifetime = lifetime + bucket.scores.normalized(to: weight)
        }

        let percentages = lifetime.normalized(to: 100)
        let slices = TravelCategory.allCases
            .map { TravelPersonalityProfile.Slice(category: $0, percentage: percentages[$0]) }
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
}
