import Foundation
import CoreLocation

struct CountryStat: Identifiable, Sendable, Hashable {
    let id: String      // ISO country code
    var name: String
    var flag: String
    var photoCount: Int
    var cities: [CityStat]
    var firstVisit: Date
    var lastVisit: Date
    var photoIDs: [String]  // GeoPhoto.id references for photo grid
    // A coordinate inside the country (from photos), independent of city geocoding,
    // so the map can place a pin before cities are resolved.
    var representativeCoordinate: GeoPhoto.Coordinate = .init(latitude: 0, longitude: 0)
    // Number of distinct trips taken to this country (separate visits over time).
    var tripCount: Int = 1

    // Bounding box of all photo locations taken in this country — the "spread" of
    // where you've been. nil when there are no photos (e.g. manually-added countries).
    var visitedBounds: GeoBounds?

    var cityCount: Int { cities.count }

    /// Country name in the app's current language (derived from the ISO code), falling
    /// back to the stored name. iOS provides these translations — no manual work needed.
    var localizedName: String { Locale.current.localizedString(forRegionCode: id) ?? name }

    /// The visited points this country's coverage is measured from: one per city that
    /// actually has photos. Shared by the Places grid's bar and the country page's map so
    /// the two can never be computed from different inputs.
    var visitedPlaces: [VisitedRegionBuilder.Place] {
        cities
            .filter { $0.photoCount > 0 }
            .map {
                VisitedRegionBuilder.Place(
                    coordinate: CLLocationCoordinate2D(latitude: $0.representativeCoordinate.latitude,
                                                       longitude: $0.representativeCoordinate.longitude),
                    countryCode: id)
            }
    }

    // Identity is the ISO code — enough for navigation routing.
    static func == (lhs: CountryStat, rhs: CountryStat) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A lat/lon bounding box, plus its approximate area on the globe.
struct GeoBounds: Sendable, Hashable {
    var minLat, maxLat, minLon, maxLon: Double

    /// Rough area of the box in km² (equirectangular approximation at the box's mean latitude).
    var areaKm2: Double {
        let meanLat = (minLat + maxLat) / 2 * .pi / 180
        let height = (maxLat - minLat) * 111.0
        let width = (maxLon - minLon) * 111.0 * cos(meanLat)
        return max(height * width, 0)
    }
}

struct CityStat: Identifiable, Sendable {
    let id: String      // "\(city),\(countryCode)"
    var name: String
    var country: String
    var countryCode: String
    var photoCount: Int
    var firstVisit: Date
    var lastVisit: Date
    var representativeCoordinate: GeoPhoto.Coordinate
}

extension CountryStat {
    static let totalCountriesInWorld = 195

    static var mock: CountryStat {
        CountryStat(
            id: "IT",
            name: "Italy",
            flag: "🇮🇹",
            photoCount: 142,
            cities: [
                CityStat(id: "Rome,IT", name: "Rome", country: "Italy", countryCode: "IT",
                         photoCount: 80, firstVisit: .distantPast, lastVisit: .now,
                         representativeCoordinate: .init(latitude: 41.9, longitude: 12.5)),
                CityStat(id: "Florence,IT", name: "Florence", country: "Italy", countryCode: "IT",
                         photoCount: 62, firstVisit: .distantPast, lastVisit: .now,
                         representativeCoordinate: .init(latitude: 43.77, longitude: 11.25))
            ],
            firstVisit: Calendar.current.date(byAdding: .year, value: -3, to: .now) ?? .now,
            lastVisit: Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now,
            photoIDs: []
        )
    }
}
