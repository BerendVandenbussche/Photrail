import Foundation

/// Raw, un-normalized category weights for a single photo (or a sum of photos).
/// Values are non-negative; they only become percentages during aggregation.
struct TravelCategoryScores: Sendable, Equatable {
    private(set) var values: [TravelCategory: Double]

    init(_ values: [TravelCategory: Double] = [:]) {
        self.values = values
    }

    mutating func add(_ category: TravelCategory, _ weight: Double) {
        guard weight > 0 else { return }
        values[category, default: 0] += weight
    }

    subscript(_ category: TravelCategory) -> Double {
        values[category] ?? 0
    }

    var total: Double {
        values.values.reduce(0, +)
    }

    static func + (lhs: TravelCategoryScores, rhs: TravelCategoryScores) -> TravelCategoryScores {
        var merged = lhs.values
        for (category, weight) in rhs.values { merged[category, default: 0] += weight }
        return TravelCategoryScores(merged)
    }

    /// Scale every weight so the vector sums to `target` (no-op when empty).
    func normalized(to target: Double = 1) -> TravelCategoryScores {
        let sum = total
        guard sum > 0 else { return self }
        return TravelCategoryScores(values.mapValues { $0 / sum * target })
    }
}
