import Foundation
import SwiftData

/// SwiftData-backed persistent record for a single geotagged photo.
/// Backed by SQLite under the hood — each photo is its own row, so geocoding
/// progress is written incrementally and never lost by a whole-file rewrite.
@Model
final class StoredPhoto {
    @Attribute(.unique) var id: String   // PHAsset.localIdentifier
    var latitude: Double
    var longitude: Double
    var date: Date
    var country: String?
    var countryCode: String?
    var city: String?
    /// True once the country has been resolved offline (the photo is "geocoded" for stats).
    var isGeocoded: Bool
    /// True once a city lookup has been attempted via CLGeocoder (success or not).
    var cityChecked: Bool
    /// Whether a real town/city (locality) was found — nil until the city pass runs.
    /// Distinguishes urban areas from countryside for the personality profile.
    var localityResolved: Bool?

    init(id: String,
         latitude: Double,
         longitude: Double,
         date: Date,
         country: String? = nil,
         countryCode: String? = nil,
         city: String? = nil,
         isGeocoded: Bool = false,
         cityChecked: Bool = false,
         localityResolved: Bool? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
        self.country = country
        self.countryCode = countryCode
        self.city = city
        self.isGeocoded = isGeocoded
        self.cityChecked = cityChecked
        self.localityResolved = localityResolved
    }
}

extension StoredPhoto {
    /// Lightweight Sendable value type used by the geocoder and statistics engine.
    var geoPhoto: GeoPhoto {
        GeoPhoto(
            id: id,
            coordinate: .init(latitude: latitude, longitude: longitude),
            date: date,
            country: country,
            countryCode: countryCode,
            city: city,
            isGeocoded: isGeocoded,
            hasLocality: localityResolved
        )
    }
}
