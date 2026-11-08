import Foundation
import CoreLocation

/// A single photo asset that has been geotagged.
/// Stored as lightweight value types — no PHAsset reference to avoid retaining the library.
struct GeoPhoto: Codable, Identifiable, Sendable {
    let id: String  // PHAsset.localIdentifier
    let coordinate: Coordinate
    let date: Date
    var country: String?
    var countryCode: String?  // ISO 3166-1 alpha-2, e.g. "IT"
    var city: String?
    var isGeocoded: Bool = false
    /// Whether a real town/city was resolved (vs. only an administrative area).
    /// nil = city lookup hasn't run yet. Used by the personality engine.
    var hasLocality: Bool? = nil
    /// GPS altitude in meters (nil if no vertical fix). Drives the Mountain personality.
    var altitude: Double? = nil

    struct Coordinate: Codable, Sendable {
        let latitude: Double
        let longitude: Double

        var clLocation: CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
    }
}

extension GeoPhoto {
    /// Higher than any summit travellers actually reach (Aconcagua is 6,961 m). A photo above
    /// it was taken from a plane — through the window at cruising altitude, 10–12 km up.
    static let maxGroundAltitude: Double = 7_000

    /// `altitude`, unless it's too high to be standing on the ground. Use this for "highest
    /// point" records: a single photo of the clouds would otherwise top every one of them.
    var groundAltitude: Double? {
        guard let altitude, altitude <= Self.maxGroundAltitude else { return nil }
        return altitude
    }

    /// Convenience flag emoji derived from ISO country code.
    var flagEmoji: String {
        guard let code = countryCode else { return "🌍" }
        return code.unicodeScalars
            .compactMap { Unicode.Scalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }
}
