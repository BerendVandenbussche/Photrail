import Foundation
import CoreLocation

/// One travel day, summed up for a postcard: which day of the trip it was, where, and the
/// route the day's photos trace. Pure data — the images are loaded separately.
struct DayPostcard: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        var clLocation: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    /// Start of the calendar day.
    let day: Date
    /// 1-based day of the trip.
    let dayNumber: Int
    /// The trip's length, when a plan says so ("Day 3 of 8").
    let totalDays: Int?
    /// The country most photographed that day.
    let countryCode: String
    /// English, like every share card.
    let countryName: String
    /// Cities in the order they were first photographed that day.
    let cities: [String]
    /// The day's photos, oldest first.
    let photoIDs: [String]
    /// Where the photos were taken, in time order, with points close together merged.
    let route: [Point]
    /// The length of `route`, straight lines between the points.
    let distanceKm: Double

    var photoCount: Int { photoIDs.count }
    var flag: String { CountryCatalog.flag(for: countryCode) }
}

enum DayPostcardBuilder {
    /// Points closer than this are one stop: a dozen photos of the same square shouldn't
    /// count as a walk.
    static let mergeMeters: Double = 200

    /// The postcard for `day`, from the trip's photos (any days — only `day`'s are used).
    /// Nil when nothing was photographed that day.
    ///
    /// - Parameters:
    ///   - tripStart: the trip's first day, for the day number when there's no plan.
    ///   - plan: the plan covering the day, if any; it supplies the day number and length.
    static func make(day: Date,
                     tripStart: Date,
                     plan: PlannedTrip?,
                     photos: [GeoPhoto],
                     calendar: Calendar = .current) -> DayPostcard? {
        let start = calendar.startOfDay(for: day)
        let dayPhotos = photos
            .filter { calendar.isDate($0.date, inSameDayAs: start) }
            .sorted { $0.date < $1.date }
        guard !dayPhotos.isEmpty else { return nil }

        let dayNumber: Int
        if let plan, let number = plan.dayNumber(now: start, calendar: calendar) {
            dayNumber = number
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: tripStart),
                                               to: start).day ?? 0
            dayNumber = max(1, days + 1)
        }

        // The country with the most photos that day; the plan's country when none resolved.
        var counts: [String: Int] = [:]
        for photo in dayPhotos { if let code = photo.countryCode { counts[code, default: 0] += 1 } }
        let code = counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key
            ?? plan?.stay(on: start, calendar: calendar)?.countryCode
            ?? ""
        let name = Locale(identifier: "en_US").localizedString(forRegionCode: code)
            ?? dayPhotos.first { $0.countryCode == code }?.country
            ?? code

        var seen = Set<String>()
        let cities = dayPhotos.compactMap(\.city).filter { seen.insert($0).inserted }

        var route: [DayPostcard.Point] = []
        var distance = 0.0
        for photo in dayPhotos {
            let point = DayPostcard.Point(latitude: photo.coordinate.latitude,
                                          longitude: photo.coordinate.longitude)
            if let last = route.last {
                let hop = last.clLocation.distance(from: point.clLocation)
                guard hop >= mergeMeters else { continue }
                distance += hop
            }
            route.append(point)
        }

        return DayPostcard(day: start,
                           dayNumber: dayNumber,
                           totalDays: plan?.length(calendar: calendar),
                           countryCode: code,
                           countryName: name,
                           cities: cities,
                           photoIDs: dayPhotos.map(\.id),
                           route: route,
                           distanceKm: distance / 1000)
    }
}
