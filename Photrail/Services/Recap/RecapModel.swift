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
    /// Trips in chronological order — the year's journey, country by country.
    let journey: [JourneyStop]

    /// Countries visited for the first time *ever* this year — the big flex.
    let newCountries: [CountryBadge]

    /// Superlatives.
    let busiestMonth: String?
    let longestTripText: String?

    /// Highest altitude reached this year (meters) + where, if above 1000 m.
    let highestAltitude: Double?
    let highestAltitudePlace: String?
    /// A mountain photo taken near the highest point, if one was found.
    let highestPeakPhotoID: String?

    /// Vision-curated "best shots" of the year (PHAsset local identifiers).
    let highlightPhotoIDs: [String]

    /// Wonders & landmarks actually seen this year (official ones first).
    let seenWonders: [WonderBadge]

    struct WonderBadge: Identifiable, Sendable {
        let id: String
        let name: String
        let emoji: String
        let isOfficial: Bool
    }

    var highestAltitudeText: String? {
        highestAltitude.map { "\(Int($0).formatted()) m" }
    }

    struct JourneyStop: Identifiable, Sendable {
        let id: Int
        let name: String
        let flag: String
        let latitude: Double
        let longitude: Double
        let monthLabel: String
    }

    struct CountryBadge: Identifiable, Sendable {
        let id: String
        let name: String
        let flag: String
    }

    var isEmpty: Bool { photos == 0 }
    var distanceText: String { "\(Int(distanceKm).formatted()) km" }

    /// A relatable, quotable comparison for the distance traveled.
    var distanceComparison: String? {
        let earth = 40_075.0, moon = 384_400.0
        guard distanceKm > 100 else { return nil }
        if distanceKm >= moon { return String(format: "%.1f× the way to the Moon", distanceKm / moon) }
        if distanceKm >= earth { return String(format: "%.1f× around the Earth", distanceKm / earth) }
        return "\(Int((distanceKm / earth * 100).rounded()))% of the way around the Earth"
    }

    static func empty(year: Int) -> RecapModel {
        RecapModel(year: year, title: "Explorer", score: 0, countries: 0, cities: 0,
                   trips: 0, photos: 0, wonders: 0, continents: 0, distanceKm: 0,
                   dominantTitle: nil, topSlices: [], favoriteCountryName: nil,
                   favoriteCountryFlag: nil, biggestTripTitle: nil,
                   biggestTripSubtitle: nil, pins: [], journey: [],
                   newCountries: [], busiestMonth: nil, longestTripText: nil,
                   highestAltitude: nil, highestAltitudePlace: nil, highestPeakPhotoID: nil,
                   highlightPhotoIDs: [], seenWonders: [])
    }
}

extension RecapModel {
    /// Build from a year-scoped `TravelStats` + personality profile.
    static func make(year: Int,
                     stats: TravelStats,
                     profile: TravelPersonalityProfile?,
                     photoCount: Int,
                     distanceKm: Double,
                     homeCountryCode: String? = nil,
                     newCountries: [CountryBadge] = [],
                     highestAltitude: Double? = nil,
                     highestAltitudePlace: String? = nil,
                     highestPeakPhotoID: String? = nil,
                     highlightPhotoIDs: [String] = []) -> RecapModel {
        let favorite = stats.mostPhotographedCountry
        // Trips away from home — your home country isn't really a "trip".
        let awayTrips = stats.trips.filter { $0.countryCode != homeCountryCode }
        let biggest = awayTrips.max { $0.photoCount < $1.photoCount }

        // Superlatives
        let busiest = stats.timelineEntries.max { $0.photoCount < $1.photoCount }?.month
        let monthNameFmt = DateFormatter()
        monthNameFmt.dateFormat = "MMMM"
        let busiestMonth = busiest.map { monthNameFmt.string(from: $0) }

        let longest = awayTrips.max {
            ($0.endDate.timeIntervalSince($0.startDate)) < ($1.endDate.timeIntervalSince($1.startDate))
        }
        let longestTripText = longest.map { "\($0.flag) \($0.country) · \($0.durationText)" }

        // Wonders & landmarks actually seen this year, official ones first.
        let seenWonders = stats.wonders
            .filter { $0.seen }
            .sorted {
                let lo = $0.wonder.category == .sevenWonders ? 0 : 1
                let ro = $1.wonder.category == .sevenWonders ? 0 : 1
                return (lo, $0.wonder.name) < (ro, $1.wonder.name)
            }
            .map { WonderBadge(id: $0.wonder.id, name: $0.wonder.name,
                               emoji: $0.wonder.emoji, isOfficial: $0.wonder.category == .sevenWonders) }

        // Chronological overview of every country visited (excluding home), ordered by
        // first visit. Built from countries — not trips — so any country with photos that
        // year is guaranteed to appear, exactly once.
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMM"
        let journey = stats.countries
            .filter { $0.id != homeCountryCode }
            .sorted { $0.firstVisit < $1.firstVisit }
            .enumerated()
            .map { index, country in
                JourneyStop(id: index, name: country.name, flag: country.flag,
                            latitude: country.representativeCoordinate.latitude,
                            longitude: country.representativeCoordinate.longitude,
                            monthLabel: monthFmt.string(from: country.firstVisit))
            }
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
                                       trips: awayTrips.count,
                                       wonders: officialWondersSeen,
                                       continents: stats.visitedContinentCount,
                                       distanceKm: distanceKm),
            countries: stats.countryCount,
            cities: stats.cityCount,
            trips: awayTrips.count,
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
                .filter { $0.latitude != 0 || $0.longitude != 0 },
            journey: journey,
            newCountries: newCountries,
            busiestMonth: busiestMonth,
            longestTripText: longestTripText,
            highestAltitude: highestAltitude,
            highestAltitudePlace: highestAltitudePlace,
            highestPeakPhotoID: highestPeakPhotoID,
            highlightPhotoIDs: highlightPhotoIDs,
            seenWonders: seenWonders
        )
    }
}
