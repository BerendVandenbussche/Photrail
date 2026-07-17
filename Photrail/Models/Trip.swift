import Foundation
import CoreLocation

/// A single trip: a continuous journey away from home, possibly spanning several
/// countries. `countryCode`/`country`/`flag` describe the *primary* (most‑photographed)
/// country for back‑compat; `countries` lists every country visited on the trip.
struct Trip: Identifiable, Sendable {
    let id: String
    let countryCode: String       // primary (most-photographed) country
    let country: String           // primary country name
    let flag: String              // primary country flag
    let countries: [TripCountry]  // every country on the trip, in order first visited
    let startDate: Date
    let endDate: Date
    let photoCount: Int
    let cities: [String]          // visited cities, most-photographed first
    let stops: [TripStop]         // visited cities with coordinates, in chronological order
    let photoIDs: [String]
    let coordinate: GeoPhoto.Coordinate   // trip centroid, for distance calculations
    /// Highest GPS altitude reached on the trip, in meters (nil if no vertical fix).
    let highestAltitude: Double?
    /// World wonders / landmarks photographed on the trip.
    let wonders: [WonderHit]

    /// A country visited during the trip.
    struct TripCountry: Identifiable, Sendable {
        let id: String            // ISO code
        var code: String { id }
        let name: String
        let flag: String
        let photoCount: Int

        /// Name in the app's language (from the ISO code) — OS-provided.
        var localizedName: String { Locale.current.localizedString(forRegionCode: code) ?? name }
        /// Always-English name (for share cards, which stay English).
        var englishName: String { Locale(identifier: "en_US").localizedString(forRegionCode: code) ?? name }
    }

    /// A city visited during the trip, with a representative location and arrival date.
    struct TripStop: Identifiable, Sendable {
        let id: String            // "city,countryCode" (cities can repeat across countries)
        let name: String
        let countryCode: String
        let flag: String
        let latitude: Double
        let longitude: Double
        let firstVisit: Date
        let photoCount: Int
    }

    var countryCodes: [String] { countries.map(\.code) }
    var isMultiCountry: Bool { countries.count > 1 }

    /// Flags of every country, e.g. "🇫🇷🇮🇹🇨🇭" (capped so rows don't overflow).
    var flagsLine: String {
        let flags = countries.prefix(6).map(\.flag).joined()
        return countries.count > 6 ? flags + "…" : flags
    }

    /// Primary country name in the app's language.
    var localizedCountry: String { Locale.current.localizedString(forRegionCode: countryCode) ?? country }

    /// A human title in the app's language: the country for single-country trips, else the countries listed.
    var displayName: String {
        guard isMultiCountry else { return localizedCountry }
        let names = countries.prefix(3).map(\.localizedName).joined(separator: ", ")
        return countries.count > 3 ? "\(names) +\(countries.count - 3)" : names
    }

    /// Same as `displayName` but always English — used on share cards.
    var englishDisplayName: String {
        let english = Locale(identifier: "en_US").localizedString(forRegionCode: countryCode) ?? country
        guard isMultiCountry else { return english }
        let names = countries.prefix(3).map(\.englishName).joined(separator: ", ")
        return countries.count > 3 ? "\(names) +\(countries.count - 3)" : names
    }

    /// A wonder/landmark seen on the trip (lightweight projection of WonderStat).
    struct WonderHit: Identifiable, Sendable {
        let id: String            // wonder id
        let name: String
        let emoji: String
        let isOfficial: Bool      // true = one of the New 7 Wonders; false = landmark
        let photoID: String?      // a representative photo, if any
    }

    /// Indicative distance traveled across the trip: sum of the legs between stops,
    /// in the order visited (kilometers). Not an exact route.
    var routeDistanceKm: Double {
        guard stops.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<stops.count {
            let a = CLLocation(latitude: stops[i - 1].latitude, longitude: stops[i - 1].longitude)
            let b = CLLocation(latitude: stops[i].latitude, longitude: stops[i].longitude)
            total += a.distance(from: b)
        }
        return total / 1000
    }

    var highestAltitudeText: String? {
        highestAltitude.map { "\(Int($0).formatted()) m" }
    }

    var dateRangeText: String { dateRange(locale: .current) }

    /// Always-English date range — for share cards, which stay English.
    var englishDateRange: String { dateRange(locale: Locale(identifier: "en_US")) }

    private func dateRange(locale: Locale) -> String {
        let fmt = DateFormatter(); fmt.locale = locale; fmt.dateFormat = "MMM d, yyyy"
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return fmt.string(from: startDate)
        }
        let short = DateFormatter(); short.locale = locale; short.dateFormat = "MMM d"
        // Same year → "Apr 3 – Apr 12, 2025"
        if Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .year) {
            return "\(short.string(from: startDate)) – \(fmt.string(from: endDate))"
        }
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    var durationText: String {
        let days = (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        return L.days(days)
    }
}
