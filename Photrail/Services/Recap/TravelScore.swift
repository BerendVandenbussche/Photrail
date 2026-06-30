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

    /// A human label for a score, so the number means something at a glance.
    /// The score blends countries, trips, wonders, continents and distance for the year.
    static func tier(for score: Int) -> String {
        switch score {
        case 85...: return "Globetrotter"
        case 65..<85: return "Adventurer"
        case 45..<65: return "Explorer"
        case 25..<45: return "Wanderer"
        default: return "Getaway"
        }
    }
}
