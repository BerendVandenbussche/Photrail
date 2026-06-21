import Foundation

/// Groups photos into trips: chronological streaks within a single country.
/// A new trip starts when the country changes or there's a long gap (you went
/// home and came back).
struct TripDetector: Sendable {

    /// Photos more than `maxGapDays` apart (even in the same country) are treated
    /// as separate trips. A short gap (a day or two without photos) keeps the same
    /// trip; about a week or more apart starts a new one.
    func detect(from photos: [GeoPhoto], maxGapDays: Int = 7) -> [Trip] {
        let sorted = photos
            .filter { $0.isGeocoded && $0.countryCode != nil }
            .sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }

        let gap = Double(maxGapDays) * 86_400
        var trips: [Trip] = []
        var current: [GeoPhoto] = []

        for photo in sorted {
            if let last = current.last {
                let sameCountry = last.countryCode == photo.countryCode
                let withinGap = photo.date.timeIntervalSince(last.date) <= gap
                if !sameCountry || !withinGap {
                    trips.append(makeTrip(current))
                    current = []
                }
            }
            current.append(photo)
        }
        if !current.isEmpty { trips.append(makeTrip(current)) }

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
