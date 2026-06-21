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

    struct Coordinate: Codable, Sendable {
        let latitude: Double
        let longitude: Double

        var clLocation: CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
    }
}

extension GeoPhoto {
    /// Convenience flag emoji derived from ISO country code.
    var flagEmoji: String {
        guard let code = countryCode else { return "🌍" }
        return code.unicodeScalars
            .compactMap { Unicode.Scalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }
}
