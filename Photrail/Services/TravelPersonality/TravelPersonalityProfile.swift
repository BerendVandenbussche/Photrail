import Foundation

/// Aggregated, percentage-based travel personality result. Codable for caching.
struct TravelPersonalityProfile: Codable, Sendable, Equatable {

    struct Slice: Codable, Sendable, Equatable, Identifiable {
        var category: TravelCategory
        var percentage: Double          // 0...100
        var id: String { category.rawValue }
    }

    /// All categories, sorted by percentage descending (sums to ~100).
    var slices: [Slice]
    /// Number of GPS photos the profile was computed from.
    var photoCount: Int
    /// 0...1 — grows with sample size; low for sparse libraries.
    var confidence: Double

    var dominantCategory: TravelCategory? {
        slices.first(where: { $0.percentage > 0 })?.category
    }

    /// Categories worth showing (skips negligible slivers).
    var visibleSlices: [Slice] {
        slices.filter { $0.percentage >= 1 }
    }

    /// Whether there's enough data to show a meaningful profile.
    var isMeaningful: Bool { photoCount >= 20 }

    var categoryPercentages: [TravelCategory: Double] {
        Dictionary(uniqueKeysWithValues: slices.map { ($0.category, $0.percentage) })
    }

    static let empty = TravelPersonalityProfile(slices: [], photoCount: 0, confidence: 0)
}
