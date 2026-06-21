import Foundation

/// A fun, informative 0–100 summary of a year's travel activity.
/// Deliberately not competitive — just a single glanceable number.
enum TravelScore {
    static func compute(countries: Int,
                        cities: Int,
                        trips: Int,
                        wonders: Int,
                        continents: Int,
                        distanceKm: Double) -> Int {
        let raw =
            Double(countries) * 6 +
            Double(cities) * 1.5 +
            Double(trips) * 4 +
            Double(wonders) * 5 +
            Double(continents) * 8 +
            min(distanceKm / 1000, 40)        // distance contributes up to ~40 pts, then plateaus
        return max(0, min(100, Int(raw.rounded())))
    }
}
