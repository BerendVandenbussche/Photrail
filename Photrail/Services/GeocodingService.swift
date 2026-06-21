import Foundation
import CoreLocation

/// Reverse-geocodes coordinates to (country, city) pairs.
/// Apple's CLGeocoder is rate-limited to roughly 1 request per second.
/// We batch geocode calls and cache results in memory to stay within the limit.
actor GeocodingService {
    private let geocoder = CLGeocoder()
    // In-memory cache keyed by a rounded coordinate string
    private var cache: [String: GeocodingResult] = [:]

    struct GeocodingResult: Sendable {
        var country: String?
        var countryCode: String?
        var city: String?
    }

    func geocode(latitude: Double, longitude: Double) async -> GeocodingResult {
        let key = cacheKey(lat: latitude, lon: longitude)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            let result = GeocodingResult(
                country: placemark?.country,
                countryCode: placemark?.isoCountryCode,
                city: placemark?.locality ?? placemark?.administrativeArea
            )
            cache[key] = result
            return result
        } catch {
            // Return empty on error — the photo is still useful without geocode data
            let empty = GeocodingResult()
            cache[key] = empty
            return empty
        }
    }

    /// Geocode a batch of GeoPhotos, inserting a delay between calls to respect rate limits.
    func geocodeBatch(_ photos: [GeoPhoto], progressHandler: @Sendable (Int) -> Void) async -> [GeoPhoto] {
        var results: [GeoPhoto] = []
        for (index, photo) in photos.enumerated() {
            var updated = photo
            if !photo.isGeocoded {
                let result = await geocode(latitude: photo.coordinate.latitude,
                                           longitude: photo.coordinate.longitude)
                updated.country = result.country
                updated.countryCode = result.countryCode
                updated.city = result.city
                updated.isGeocoded = true
                // Respect CLGeocoder rate limit: ~1 req/sec
                try? await Task.sleep(nanoseconds: 1_050_000_000)
            }
            results.append(updated)
            progressHandler(index + 1)
        }
        return results
    }

    private func cacheKey(lat: Double, lon: Double) -> String {
        // Round to ~1km precision to maximise cache hits for nearby photos
        String(format: "%.2f,%.2f", lat, lon)
    }
}
