import SwiftUI

/// A secret milestone the user can earn purely from their travel history. Locked
/// achievements are hidden entirely (mystery tiles) until the rule is satisfied,
/// then celebrated with a one-time confetti toast. Everything is derived on-device
/// from `TravelStats` — no new scanning or network.
struct Achievement: Identifiable {
    let id: String
    let emoji: String
    let title: LocalizedStringKey
    /// How it was earned — shown only once unlocked.
    let detail: LocalizedStringKey
    /// Evaluated against the current lifetime stats. Pure, side-effect free.
    let isUnlocked: (TravelStats) -> Bool
}

/// Rules that need a little more than a single stat comparison.
enum AchievementRules {
    /// Photos taken in both the northern and southern hemispheres (via country coords).
    static func bothHemispheres(_ stats: TravelStats) -> Bool {
        var north = false, south = false
        for country in stats.countries {
            let lat = country.representativeCoordinate.latitude
            if lat == 0 { continue }        // unresolved coordinate — skip
            if lat > 0 { north = true } else { south = true }
            if north && south { return true }
        }
        return false
    }

    /// All seven "New 7 Wonders of the World" seen (landmarks don't count).
    static func allSevenWonders(_ stats: TravelStats) -> Bool {
        let seven = stats.wonders.filter { $0.wonder.category == .sevenWonders }
        return !seven.isEmpty && seven.allSatisfy(\.seen)
    }
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(id: "countries10", emoji: "🗺️", title: "Globetrotter",
                    detail: "Visited 10 countries",
                    isUnlocked: { $0.countryCount >= 10 }),
        Achievement(id: "countries25", emoji: "🌐", title: "World Wanderer",
                    detail: "Visited 25 countries",
                    isUnlocked: { $0.countryCount >= 25 }),
        Achievement(id: "countries50", emoji: "🌏", title: "Half the World",
                    detail: "Visited 50 countries",
                    isUnlocked: { $0.countryCount >= 50 }),
        Achievement(id: "cities50", emoji: "🏙️", title: "City Slicker",
                    detail: "Explored 50 cities",
                    isUnlocked: { $0.cityCount >= 50 }),
        Achievement(id: "continents3", emoji: "🧭", title: "Continent Hopper",
                    detail: "Set foot on 3 continents",
                    isUnlocked: { $0.visitedContinentCount >= 3 }),
        Achievement(id: "continentsAll", emoji: "🌎", title: "Around the World",
                    detail: "Visited every inhabited continent",
                    isUnlocked: { $0.visitedContinentCount >= $0.visitableContinentCount }),
        Achievement(id: "antarctica", emoji: "🐧", title: "Polar Pioneer",
                    detail: "Reached Antarctica",
                    isUnlocked: { $0.hasVisitedAntarctica }),
        Achievement(id: "sevenWonders", emoji: "🏆", title: "Wonder Master",
                    detail: "Saw all 7 New Wonders of the World",
                    isUnlocked: AchievementRules.allSevenWonders),
        Achievement(id: "hemispheres", emoji: "🌗", title: "Hemisphere Hopper",
                    detail: "Took photos in both hemispheres",
                    isUnlocked: AchievementRules.bothHemispheres),
        Achievement(id: "trips25", emoji: "✈️", title: "Frequent Flyer",
                    detail: "Took 25 trips",
                    isUnlocked: { $0.trips.count >= 25 }),
        Achievement(id: "photos10k", emoji: "📸", title: "Shutterbug",
                    detail: "Geotagged 10,000 photos",
                    isUnlocked: { $0.totalGeotaggedPhotos >= 10_000 }),
    ]

    static var count: Int { all.count }
}
