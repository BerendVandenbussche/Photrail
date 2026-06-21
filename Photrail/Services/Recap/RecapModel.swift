import Foundation

/// All data for the Year in Travel recap, computed for a single year.
struct RecapModel: Sendable, Identifiable {
    var id: Int { year }
    let year: Int
    let title: String              // hero travel title, e.g. "Urban Explorer"
    let score: Int                 // 0–100

    let countries: Int
    let cities: Int
    let trips: Int
    let photos: Int
    let wonders: Int
    let continents: Int

    let distanceKm: Double

    let dominantTitle: String?     // personality category title, e.g. "Urban Explorer"
    let topSlices: [TravelPersonalityProfile.Slice]

    let favoriteCountryName: String?
    let favoriteCountryFlag: String?

    let biggestTripTitle: String?
    let biggestTripSubtitle: String?

    let pins: [GeoPhoto.Coordinate]

    var isEmpty: Bool { photos == 0 }
    var distanceText: String { "\(Int(distanceKm).formatted()) km" }

    static func empty(year: Int) -> RecapModel {
        RecapModel(year: year, title: "Explorer", score: 0, countries: 0, cities: 0,
                   trips: 0, photos: 0, wonders: 0, continents: 0, distanceKm: 0,
                   dominantTitle: nil, topSlices: [], favoriteCountryName: nil,
                   favoriteCountryFlag: nil, biggestTripTitle: nil,
                   biggestTripSubtitle: nil, pins: [])
    }
}

extension RecapModel {
    /// Build from a year-scoped `TravelStats` + personality profile.
    static func make(year: Int,
                     stats: TravelStats,
                     profile: TravelPersonalityProfile?,
                     photoCount: Int,
                     distanceKm: Double) -> RecapModel {
        let favorite = stats.mostPhotographedCountry
        let biggest = stats.trips.max { $0.photoCount < $1.photoCount }
        // "Wonders" means the official New 7 Wonders — not the broader landmark catalog.
        let officialWondersSeen = stats.wonders
            .filter { $0.wonder.category == .sevenWonders && $0.seen }
            .count

        return RecapModel(
            year: year,
            title: TravelTitle.generate(profile: profile,
                                        countries: stats.countryCount,
                                        continents: stats.visitedContinentCount,
                                        trips: stats.trips.count),
            score: TravelScore.compute(countries: stats.countryCount,
                                       cities: stats.cityCount,
                                       trips: stats.trips.count,
                                       wonders: officialWondersSeen,
                                       continents: stats.visitedContinentCount,
                                       distanceKm: distanceKm),
            countries: stats.countryCount,
            cities: stats.cityCount,
            trips: stats.trips.count,
            photos: photoCount,
            wonders: officialWondersSeen,
            continents: stats.visitedContinentCount,
            distanceKm: distanceKm,
            dominantTitle: profile?.dominantCategory?.title,
            topSlices: Array((profile?.visibleSlices ?? []).prefix(3)),
            favoriteCountryName: favorite?.name,
            favoriteCountryFlag: favorite?.flag,
            biggestTripTitle: biggest.map { "\($0.flag) \($0.country)" },
            biggestTripSubtitle: biggest.map { "\($0.photoCount) photos · \($0.dateRangeText)" },
            pins: stats.countries
                .map { $0.representativeCoordinate }
                .filter { $0.latitude != 0 || $0.longitude != 0 }
        )
    }
}
