import Foundation

/// A trip the user entered by hand — for journeys whose photos are gone (or were never
/// on this device) so the country/continent/world stats stay accurate. Purely additive.
///
/// Each manual trip carries the countries visited (each with optional Apple-Maps-geocoded
/// places) and an optional date range. When dated, the `StatisticsEngine` synthesizes a
/// real `Trip` from it so it appears in the Trips list alongside photo trips; undated
/// entries (e.g. migrated from the old "manual countries" feature) still feed the country
/// stats but don't show as a trip row.
struct ManualTrip: Codable, Sendable, Identifiable {
    let id: String                 // stable UUID string
    var name: String?              // optional custom title
    var startDate: Date?           // nil = undated (migrated); dated trips show as a Trip
    var endDate: Date?
    var countries: [Country]

    /// A country visited on a manual trip, with the places recorded within it.
    struct Country: Codable, Sendable, Identifiable {
        let code: String           // ISO 3166-1 alpha-2
        var name: String
        var flag: String
        var latitude: Double?      // representative point for the map pin (nil if unknown)
        var longitude: Double?
        var places: [Place] = []

        var id: String { code }
    }

    /// A place (city / point) added via Apple Maps geocoding, scoped to a country.
    struct Place: Codable, Sendable, Identifiable {
        let id: String             // stable UUID string
        var name: String
        var latitude: Double
        var longitude: Double
    }

    /// True once the trip has a usable date range (both ends set).
    var isDated: Bool { startDate != nil && endDate != nil }

    /// The country codes on this trip.
    var countryCodes: [String] { countries.map(\.code) }
}
