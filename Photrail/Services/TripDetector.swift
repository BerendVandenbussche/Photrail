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

        // Cities by frequency
        var cityCounts: [String: Int] = [:]
        for photo in photos { if let c = photo.city { cityCounts[c, default: 0] += 1 } }
        let cities = cityCounts.sorted { $0.value > $1.value }.map(\.key)

        // Centroid
        let lat = photos.map(\.coordinate.latitude).reduce(0, +) / Double(photos.count)
        let lon = photos.map(\.coordinate.longitude).reduce(0, +) / Double(photos.count)

        let start = photos.map(\.date).min() ?? first.date
        let end = photos.map(\.date).max() ?? first.date

        return Trip(
            id: "\(code)-\(Int(start.timeIntervalSince1970))",
            countryCode: code,
            country: first.country ?? code,
            flag: first.flagEmoji,
            startDate: start,
            endDate: end,
            photoCount: photos.count,
            cities: cities,
            photoIDs: photos.map(\.id),
            coordinate: .init(latitude: lat, longitude: lon)
        )
    }
}
