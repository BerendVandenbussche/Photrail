import Foundation
import CoreLocation

/// Pure transformation: [GeoPhoto] → "On this day" memories.
/// Finds photos taken on today's calendar day (month + day) in earlier years,
/// away from home, grouped per (year, country). No side effects, fully testable.
struct MemoriesEngine: Sendable {
    /// - Parameters:
    ///   - homeCoordinate: when set, photos within `homeRadiusKm` are excluded (preferred,
    ///     matches the personality engine — keeps domestic trips far from home as memories).
    ///   - homeCountryCode: fallback exclusion when no home coordinate is known.
    ///   - homeRadiusKm: exclusion radius around home, in kilometers.
    func memories(from photos: [GeoPhoto],
                  homeCoordinate: GeoPhoto.Coordinate? = nil,
                  homeCountryCode: String? = nil,
                  homeRadiusKm: Double = 50,
                  on today: Date = Date(),
                  calendar: Calendar = .current) -> [Memory] {
        let todayMonth = calendar.component(.month, from: today)
        let todayDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)
        let homeLocation = homeCoordinate?.clLocation

        // Photos from this exact day-of-year, in a past year, away from home.
        let matching = photos.filter { photo in
            guard photo.isGeocoded, photo.countryCode != nil else { return false }

            // Exclude everyday photos near home. Prefer a precise radius; fall back to
            // home country only when we don't have a home coordinate at all.
            if let homeLocation {
                if photo.coordinate.clLocation.distance(from: homeLocation) <= homeRadiusKm * 1000 {
                    return false
                }
            } else if let homeCountryCode, photo.countryCode == homeCountryCode {
                return false
            }

            let comps = calendar.dateComponents([.year, .month, .day], from: photo.date)
            return comps.month == todayMonth && comps.day == todayDay
                && (comps.year ?? currentYear) < currentYear
        }
        guard !matching.isEmpty else { return [] }

        // Group by year + country.
        var groups: [String: [GeoPhoto]] = [:]
        for photo in matching {
            let year = calendar.component(.year, from: photo.date)
            groups["\(year)-\(photo.countryCode!)", default: []].append(photo)
        }

        return groups.values.map { groupPhotos -> Memory in
            let sorted = groupPhotos.sorted { $0.date < $1.date }
            let first = sorted[0]
            let year = calendar.component(.year, from: first.date)

            // Most-photographed city that day.
            var cityCounts: [String: Int] = [:]
            for photo in sorted { if let c = photo.city { cityCounts[c, default: 0] += 1 } }
            let city = cityCounts.max { $0.value < $1.value }?.key

            return Memory(
                id: "\(year)-\(first.countryCode!)",
                year: year,
                yearsAgo: currentYear - year,
                date: first.date,
                country: first.country ?? first.countryCode!,
                countryCode: first.countryCode!,
                flag: first.flagEmoji,
                city: city,
                photoIDs: sorted.map(\.id)
            )
        }
        .sorted { $0.year > $1.year }   // most recent year first
    }
}
