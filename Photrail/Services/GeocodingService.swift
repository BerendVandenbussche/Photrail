import Foundation
import CoreLocation

/// Reverse-geocodes coordinates to city names via Apple's CLGeocoder.
/// Countries are resolved offline (see `OfflineCountryGeocoder`); this service is
/// only used for the optional city enrichment pass, which is rate-limited (~1 req/s).
actor GeocodingService {
    private let geocoder = CLGeocoder()
    // Cache keyed by a rounded coordinate string.
    private var cache: [String: CityResult] = [:]

    /// `city` is the display name (locality, or administrativeArea as a fallback).
    /// `hasLocality` is true only when a real town/city was returned — the signal that
    /// distinguishes an actual urban area from open countryside.
    struct CityResult: Sendable {
        let city: String?
        let hasLocality: Bool
    }

    /// Reverse geocode a single coordinate.
    func city(latitude: Double, longitude: Double) async -> CityResult {
        let key = cacheKey(lat: latitude, lon: longitude)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        let result = CityResult(city: placemark?.locality ?? placemark?.administrativeArea,
                                hasLocality: placemark?.locality != nil)
        cache[key] = result
        return result
    }

    /// Geocode a batch of photos to cities. `onResult` is awaited per photo so the
    /// caller can persist each result before the next lookup. The rate-limit delay
    /// only applies after an actual network request (cache hits are instant).
    func cityBatch(_ photos: [GeoPhoto],
                   onResult: @Sendable (Int, String, CityResult) async -> Void) async {
        for (index, photo) in photos.enumerated() {
            let key = cacheKey(lat: photo.coordinate.latitude, lon: photo.coordinate.longitude)
            let wasCached = cache[key] != nil

            let result = await city(latitude: photo.coordinate.latitude,
                                    longitude: photo.coordinate.longitude)
            await onResult(index + 1, photo.id, result)

            if !wasCached {
                guard !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: 1_050_000_000)
            }
            if Task.isCancelled { break }
        }
    }

    private func cacheKey(lat: Double, lon: Double) -> String {
        String(format: "%.2f,%.2f", lat, lon)
    }
}
