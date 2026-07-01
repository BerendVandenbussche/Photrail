import Foundation
import CoreLocation

/// Groups photos into trips. A trip is a continuous journey away from home that may
/// span several countries. Walking photos in time order, a trip ends when:
///  - a photo is taken back in the home town (you're home), or
///  - there's a gap longer than `maxGapDays` — *unless* the next photo is in the same
///    country and the gap is still within `sameCountryMaxGapDays` (a long single-country
///    stay shouldn't be split, but two separate visits months apart should be).
struct TripDetector: Sendable {

    /// - Parameters:
    ///   - maxGapDays: a gap beyond this ends the trip (default a week).
    ///   - sameCountryMaxGapDays: the longest gap the "same country → keep going" exception
    ///     tolerates, so two separate trips to one country don't merge into one.
    ///   - homeCoordinate / homeRadiusKm: a photo within this radius of home ends the trip.
    ///   - homeCountryCode: fallback home boundary when no home coordinate is known.
    func detect(from photos: [GeoPhoto],
                maxGapDays: Int = 7,
                sameCountryMaxGapDays: Int = 30,
                homeCoordinate: GeoPhoto.Coordinate? = nil,
                homeCountryCode: String? = nil,
                homeRadiusKm: Double = 50) -> [Trip] {
        let relevant = photos
            .filter { $0.isGeocoded && $0.countryCode != nil }
            .sorted { $0.date < $1.date }
        guard !relevant.isEmpty else { return [] }

        let gap = Double(maxGapDays) * 86_400
        let sameCountryGap = Double(sameCountryMaxGapDays) * 86_400
        let homeLocation = homeCoordinate?.clLocation

        func isHome(_ photo: GeoPhoto) -> Bool {
            if let homeLocation {
                return photo.coordinate.clLocation.distance(from: homeLocation) <= homeRadiusKm * 1000
            }
            if let homeCountryCode { return photo.countryCode == homeCountryCode }
            return false
        }

        var trips: [Trip] = []
        var current: [GeoPhoto] = []

        for photo in relevant {
            // Back home → the current journey is over.
            if isHome(photo) {
                if !current.isEmpty { trips.append(makeTrip(current)); current = [] }
                continue
            }
            guard let last = current.last else { current = [photo]; continue }

            let elapsed = photo.date.timeIntervalSince(last.date)
            if elapsed <= gap {
                current.append(photo)                                  // still the same journey
            } else if photo.countryCode == last.countryCode && elapsed <= sameCountryGap {
                current.append(photo)                                  // same-country long stay
            } else {
                trips.append(makeTrip(current)); current = [photo]     // new journey
            }
        }
        if !current.isEmpty { trips.append(makeTrip(current)) }

        return trips.sorted { $0.startDate > $1.startDate }
    }

    private func makeTrip(_ photos: [GeoPhoto]) -> Trip {
        let first = photos.first!

        // Countries on the trip, ordered by first appearance; primary = most photographed.
        var countryPhotos: [String: [GeoPhoto]] = [:]
        var countryOrder: [String] = []
        for photo in photos {
            guard let code = photo.countryCode else { continue }
            if countryPhotos[code] == nil { countryOrder.append(code) }
            countryPhotos[code, default: []].append(photo)
        }
        let countries: [Trip.TripCountry] = countryOrder.map { code in
            let ps = countryPhotos[code]!
            return Trip.TripCountry(id: code,
                                    name: ps.first?.country ?? code,
                                    flag: ps.first?.flagEmoji ?? "🌍",
                                    photoCount: ps.count)
        }
        let primary = countries.max { $0.photoCount < $1.photoCount } ?? countries.first!

        // Cities → located stops (keyed by city + country, since names repeat across borders).
        var byCity: [String: [GeoPhoto]] = [:]
        for photo in photos {
            guard let city = photo.city, let code = photo.countryCode else { continue }
            byCity["\(city),\(code)", default: []].append(photo)
        }
        let cities = byCity.sorted { $0.value.count > $1.value.count }
            .compactMap { $0.value.first?.city }
        let stops = byCity.map { key, cityPhotos -> Trip.TripStop in
            let count = Double(cityPhotos.count)
            let clat = cityPhotos.map(\.coordinate.latitude).reduce(0, +) / count
            let clon = cityPhotos.map(\.coordinate.longitude).reduce(0, +) / count
            let firstVisit = cityPhotos.map(\.date).min() ?? first.date
            let sample = cityPhotos.first!
            return Trip.TripStop(id: key, name: sample.city ?? key,
                                 countryCode: sample.countryCode ?? "",
                                 flag: sample.flagEmoji,
                                 latitude: clat, longitude: clon,
                                 firstVisit: firstVisit, photoCount: cityPhotos.count)
        }
        .sorted { $0.firstVisit < $1.firstVisit }

        // Centroid
        let lat = photos.map(\.coordinate.latitude).reduce(0, +) / Double(photos.count)
        let lon = photos.map(\.coordinate.longitude).reduce(0, +) / Double(photos.count)

        let start = photos.map(\.date).min() ?? first.date
        let end = photos.map(\.date).max() ?? first.date

        let highestAltitude = photos.compactMap(\.altitude).max()

        let wonders = WonderDetector().detect(photos: photos)
            .filter { $0.photoCount > 0 }
            .map { Trip.WonderHit(id: $0.wonder.id, name: $0.wonder.name,
                                  emoji: $0.wonder.emoji,
                                  isOfficial: $0.wonder.category == .sevenWonders,
                                  photoID: $0.representativePhotoID) }

        return Trip(
            id: "\(primary.code)-\(Int(start.timeIntervalSince1970))",
            countryCode: primary.code,
            country: primary.name,
            flag: primary.flag,
            countries: countries,
            startDate: start,
            endDate: end,
            photoCount: photos.count,
            cities: cities,
            stops: stops,
            photoIDs: photos.map(\.id),
            coordinate: .init(latitude: lat, longitude: lon),
            highestAltitude: highestAltitude,
            wonders: wonders
        )
    }
}
