import Foundation

/// A country the user visited but has no (remaining) photos for — added by hand so
/// the stats stay accurate. Purely additive; can't produce photo-based share cards.
struct ManualCountry: Codable, Sendable, Identifiable {
    let code: String            // ISO 3166-1 alpha-2
    var name: String
    var flag: String
    var latitude: Double?       // representative point, for the map pin (nil if unknown)
    var longitude: Double?

    var id: String { code }
}
