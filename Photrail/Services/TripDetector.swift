import Foundation

/// Groups photos into trips. A trip is a stay in one country; consecutive photos
/// in that country within `maxGapDays` belong to the same trip — even if you
/// briefly crossed into a neighbouring country, because grouping happens per
/// country first. Home-country photos are excluded (home life isn't a trip).
struct TripDetector: Sendable {

    /// - Parameters:
    ///   - maxGapDays: a gap of about a week in the same country starts a new trip.
    ///   - homeCountryCode: excluded entirely, so everyday home photos don't form trips.
    func detect(from photos: [GeoPhoto], maxGapDays: Int = 7, homeCountryCode: String? = nil) -> [Trip] {
        let relevant = photos.filter {
            $0.isGeocoded && $0.countryCode != nil && $0.countryCode != homeCountryCode
        }
        guard !relevant.isEmpty else { return [] }

        let gap = Double(maxGapDays) * 86_400
        var trips: [Trip] = []

        // Group per country first, then split each country's photos by time gap.
        // This keeps a multi-country journey from fragmenting one country's stay
        // into several trips just because another country's photos interleave.
        for (_, countryPhotos) in Dictionary(grouping: relevant, by: { $0.countryCode! }) {
            let sorted = countryPhotos.sorted { $0.date < $1.date }
            var current: [GeoPhoto] = []
            for photo in sorted {
                if let last = current.last, photo.date.timeIntervalSince(last.date) > gap {
                    trips.append(makeTrip(current))
                    current = []
                }
                current.append(photo)
            }
            if !current.isEmpty { trips.append(makeTrip(current)) }
        }

        return trips.sorted { $0.startDate > $1.startDate }
    }

    private func makeTrip(_ photos: [GeoPhoto]) -> Trip {
        let first = photos.first!
        let code = first.countryCode ?? ""

        // Group photos by city for both frequency ordering and located stops.
        var byCity: [String: [GeoPhoto]] = [:]
        for photo in photos { if let c = photo.city { byCity[c, default: []].append(photo) } }

        // Cities by frequency (most-photographed first)
        let cities = byCity.sorted { $0.value.count > $1.value.count }.map(\.key)

        // Located stops, in the order they were first visited — drives the trip map line.
        let stops = byCity.map { name, cityPhotos -> Trip.TripStop in
            let count = Double(cityPhotos.count)
            let clat = cityPhotos.map(\.coordinate.latitude).reduce(0, +) / count
            let clon = cityPhotos.map(\.coordinate.longitude).reduce(0, +) / count
            let firstVisit = cityPhotos.map(\.date).min() ?? first.date
            return Trip.TripStop(id: name, latitude: clat, longitude: clon,
                                 firstVisit: firstVisit, photoCount: cityPhotos.count)
        }
        .sorted { $0.firstVisit < $1.firstVisit }

        // Centroid
        let lat = photos.map(\.coordinate.latitude).reduce(0, +) / Double(photos.count)
        let lon = photos.map(\.coordinate.longitude).reduce(0, +) / Double(photos.count)

        let start = photos.map(\.date).min() ?? first.date
        let end = photos.map(\.date).max() ?? first.date

        // Highest altitude reached on the trip.
        let highestAltitude = photos.compactMap(\.altitude).max()

        // Wonders / landmarks photographed on the trip.
        let wonders = WonderDetector().detect(photos: photos)
            .filter { $0.photoCount > 0 }
            .map { Trip.WonderHit(id: $0.wonder.id, name: $0.wonder.name,
                                  emoji: $0.wonder.emoji,
                                  isOfficial: $0.wonder.category == .sevenWonders,
                                  photoID: $0.representativePhotoID) }

        return Trip(
            id: "\(code)-\(Int(start.timeIntervalSince1970))",
            countryCode: code,
            country: first.country ?? code,
            flag: first.flagEmoji,
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
